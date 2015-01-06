package App::Catalogue::Controller::Publication;

use lib qw(/srv/www/sbcat/lib/extension);
use Catmandu::Sane;
use Catmandu;
use App::Helper;
use App::Catalogue::Controller::Corrector qw/delete_empty_fields correct_hash_array correct_writer correct_publid/;
use App::Catalogue::Controller::File qw/handle_file delete_file/;
use Catmandu::Validator::PUB;
use Hash::Merge qw/merge/;
use Carp;
use JSON;
use HTML::Entities;
use Exporter qw/import/;
our @EXPORT = qw/new_publication save_publication delete_publication update_publication edit_publication/;

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

    my $json = new JSON;

    $data = delete_empty_fields($data);
    $data = correct_hash_array($data);

    $data = correct_writer($data) if $data->{writer};
    $data = correct_publid($data);

    # html encoding
    foreach (qw/message/) {
        $data->{$_} = encode_entities($data->{$_});
    }


    if($data->{file}){
    	$data->{file} = handle_file($data);
    }

    if($data->{language}){
    	foreach my $lang (@{$data->{language}}){
    		if($lang->{name} eq "English" or $lang->{name} eq "German"){
    			$lang->{iso} = h->config->{lists}->{language_preselect}->{$lang->{name}};
    		}
    		else {
    			$lang->{iso} = h->config->{lists}->{language}->{$lang->{name}};
    		}
    	}
    }
    if($data->{abstract}){
    	my $i = 0;
    	foreach my $ab (@{$data->{abstract}}){
    		if($ab->{lang} and !$ab->{text}){
    			splice @{$data->{abstract}}, $i, 1;
    		}
    		$i++;
    	}
    }

    $data = delete_empty_fields($data);
    if($data->{finalSubmit} and $data->{finalSubmit} eq "recPublish"){
    	$data->{status} = "public";
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

    $data->{date_updated} = h->now();
    $data->{date_created} = $data->{date_updated} if !$data->{date_created};

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

	my $status = delete_file($id);

    # delete attached files
#    my $dir = h->config->{upload_dir} ."/$id";
#    my $status = rmdir $dir if -e $dir || 0;
#    croak "Error: could not delete files" if $status;

    # delete citations
    my $citbag = Catmandu->store('citation')->bag;
    $citbag->delete($id);
}

1;
