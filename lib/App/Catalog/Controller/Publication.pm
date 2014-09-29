package App::Catalog::Controller::Publication;

use lib qw(/srv/www/sbcat/lib/extension);
use Catmandu::Sane;
use Catmandu;
use App::Catalog::Helper;
use Catmandu::Validator::PUB;
use Hash::Merge qw/merge/;
use Carp;
use JSON;
use HTML::Entities;
use Exporter qw/import/;
our @EXPORT
    = qw/new_publication save_publication delete_publication update_publication edit_publication/;

sub _create_id {
    my $id = h->bag->get('1')->{"latest"};
    $id++;
    h->bag->add( { _id => "1", latest => $id } );
    return $id;
}

sub new_publication {
    return _create_id;
}

sub save_publication {
    my $data      = shift;
    #my $validator = Catmandu::Validator::PUB->new();

    foreach my $key (keys %$data){
    	my $ref = ref $data->{$key};

    	if($ref eq "ARRAY"){
    		if(!$data->{$key}->[0]){
    			delete $data->{$key};
    		}
    	}
    	elsif($ref eq "HASH"){
    		if(!%{$data->{$key}}){
    			delete $data->{$key};
    		}
    	}
    	else{
    		if($data->{$key} and $data->{$key} eq ""){
    			delete $data->{$key};
    		}
    	}
    }

    my $json = new JSON;

    # html encoding
    foreach (qw/message/) {
        $data->{$_} = encode_entities($data->{$_});
    }

    if($data->{author}){
    	if(ref $data->{author} ne "ARRAY"){
    		$data->{author} = [$data->{author}];
    	}
#    	my $author = ();
#    	foreach (@{$data->{author}}){
#    		push @$author, $json->decode($_);
#    	}
#    	$data->{author} = $author;
    }
    return $data;
    if($data->{editor}){
    	if(ref $data->{editor} ne "ARRAY"){
    		$data->{editor} = [$data->{editor}];
    	}
#    	my $editor = ();
#    	foreach (@{$data->{editor}}){
#    		push @$editor, $json->decode($_);
#    	}
#    	$data->{editor} = $editor;
    }
    if($data->{translator}){
    	if(ref $data->{translator} ne "ARRAY"){
    		$data->{translator} = [$data->{translator}];
    	}
#    	my $translator = ();
#    	foreach (@{$data->{translator}}){
#    		push @$translator, $json->decode($_);
#    	}
#    	$data->{translator} = $translator;
    }
    if($data->{file}){
    	if(ref $data->{file} ne "ARRAY"){
    		$data->{file} = [$data->{file}];
    	}
    	if(ref $data->{file_order} ne "ARRAY"){
    		$data->{file_order} = [$data->{file_order}];
    	}
    	my $file = ();
    	foreach my $recfile (@{$data->{file}}){
    		my $rfile = $json->decode($recfile);
    		my @array = @{$data->{file_order}};
    		my $search_for = $rfile->{file_id};
    		my( $index )= grep { $array[$_] eq $search_for } 0..$#array;
    		$rfile->{file_order} = sprintf("%03d", $index);
    		$rfile->{file_json} = $recfile;
    		push @$file, $rfile;
    	}
    	$data->{file} = $file;
    }
    if($data->{related_material}){
    	if(ref $data->{related_material} ne "ARRAY"){
    		$data->{related_material} = [$data->{related_material}];
    	}
    	my $relmat = ();
    	foreach (@{$data->{related_material}}){
    		next if $_ eq "";
    		push @$relmat, $json->decode($_);
    	}
    	$data->{related_material} = $relmat;
    }
    if($data->{language}){
    	if(ref $data->{language} ne "ARRAY"){
    		$data->{language} = [$data->{language}];
    	}
#    	foreach my $lang (@{$data->{language}}){
#    		my $language;
#    		$language->{text} = $lang;
#    		if($lang eq "English" or $lang eq "German"){
#    			$language->{iso} = h->config->{lists}->{language_preselect}->{$lang};
#    		}
#    		else {
#    			$language->{iso} = h->config->{lists}->{language}->{$lang};
#    		}
#    		$lang = $language;
#    	}
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
    my $publbag = Catmandu->store->bag('publication');
    $data->{citation} = $citbag->get($data->{_id}) if $data->{_id};

    my $pre_fixer = Catmandu::Fix->new(
    fixes => [
        'clean_department_project()',
    ]);

    #if ( $validator->is_valid($data) ) {

    	$pre_fixer->fix($data);
        my $result = h->publication->add($data);
        $publbag->add($result);
        h->publication->commit;
        return $result;
    #}
    #else {
    #    croak join(@{$validator->last_errors}, ' | ');
    #}

}

sub update_publication {
    my $data = shift;
    croak "Error: No _id specified" unless $data->{_id};

    #my $old = h->publication->get( $data->{_id} );
    #my $merger = Hash::Merge->new();
    #left precedence by default!
    #my $new = $merger->merge( $data, $old );

    my $result = save_publication($data);
    return $result;
}

sub edit_publication {
    my $id = shift;
    croak "Error: No id specified." unless $id;

    h->publication->get($id);
}

sub delete_publication {
	my $id = shift;
    croak "Error: No id provided." unless $id;

    my $del = {
        _id => $id,
        date_deleted => h->now,
        status => 'deleted',
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
    $citbag->delete($id);
}

1;
