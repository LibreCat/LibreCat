package App::Catalog::Controller::Publication;

use lib qw(/srv/www/sbcat/lib/extension);
use Catmandu::Sane;
use Catmandu;
use App::Catalog::Helper;
use Catmandu::Validator::PUB;
use Hash::Merge qw/merge/;
use Carp;
use JSON;
use Exporter qw/import/;
our @EXPORT
    = qw/new_publication save_publication delete_publication update_publication edit_publication/;

# Catmandu->load;
# Catmandu->config;

sub _create_id {
    my $bag = h->bag->get('1');
    my $id  = $bag->{"latest"};
    $id++;
    $bag = h->bag->add( { _id => "1", latest => $id } );
    return $id;
}

sub new_publication {
    return _create_id;
}

sub save_publication {
    my $data      = shift;
    #my $validator = Catmandu::Validator::PUB->new();
    my $json = new JSON;
    
    if($data->{author}){
    	if(ref $data->{author} ne "ARRAY"){
    		$data->{author} = [$data->{author}];
    	}
    	my $author = ();
    	foreach (@{$data->{author}}){
    		push @$author, $json->decode($_);
    	}
    	$data->{author} = $author;
    }
    if($data->{editor}){
    	if(ref $data->{editor} ne "ARRAY"){
    		$data->{editor} = [$data->{editor}];
    	}
    	my $editor = ();
    	foreach (@{$data->{editor}}){
    		push @$editor, $json->decode($_);
    	}
    	$data->{editor} = $editor;
    }
    if($data->{translator}){
    	if(ref $data->{translator} ne "ARRAY"){
    		$data->{translator} = [$data->{translator}];
    	}
    	my $translator = ();
    	foreach (@{$data->{translator}}){
    		push @$translator, $json->decode($_);
    	}
    	$data->{translator} = $translator;
    }
    
    foreach my $key (keys %$data){
    	if(!$data->{$key}){
    		delete $data->{$key};
    	}
    }
    
    # citations
    use Citation;
    my $response = Citation::id2citation($data);
    my $citbag = Catmandu->store('citation')->bag;
    $data->{citation} = $citbag->get($data->{_id}) if $data->{_id};

    #if ( $validator->is_valid($data) ) {
    	
        my $result = h->publication->add($data);
        h->publication->commit;
        #return $response;
    #}
    #else {
    #    croak join(@{$validator->last_errors}, ' | ');
    #}

}

sub update_publication {
    my $data = shift;
    croak "Error: No _id specified" unless $data->{_id};

    my $old = h->publication->get( $data->{_id} );
    my $merger = Hash::Merge->new(); 
    #left precedence by default!
    my $new = $merger->merge( $data, $old );

    my $result = save_publication($new);
    #return $result;
}

sub edit_publication {
    my $id = shift;

    return "Error" unless $id;
    # some pre-processing needed?
    h->publication->get($id);
}

sub delete_publication {
	my $id = shift;
    return "Error" unless $id;

    my $now = "";
    my $del = {
        _id => $id,
        date_deleted => $now,
    };

    # this will do a hard override of
    # the existing publication
	h->publication->add($del);
	h->publication->commit;

    # delete attached files
    my $dir = h->config->{upload_dir} ."/$id";
    my $status = rmdir $dir if -e $dir || 0;
    croak "Error: could not delete files" if $status;
    
    # delete citations
    my $citbag = Catmandu->store('citation')->bag;
    $citbag->delete($id) if $id;
}

1;
