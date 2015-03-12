package App::Catalogue::Controller::Publication;

use Catmandu::Sane;
use Catmandu;
use Catmandu::Fix qw/maybe_add_urn/;
use App::Helper;
use App::Catalogue::Controller::Corrector qw/delete_empty_fields correct_hash_array correct_writer correct_publid/;
use App::Catalogue::Controller::File qw/handle_file delete_file/;
use App::Catalogue::Controller::Material qw/update_related_material/;
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

sub update_publication {
    my $data = shift;

    $data->{_id} = new_publication() unless $data->{_id};

    $data = correct_publid($data);
    $data = correct_hash_array($data);

    $data = correct_writer($data);
    $data = delete_empty_fields($data);

    # html encoding??
    foreach (qw/message/) {
        $data->{$_} = encode_entities($data->{$_}) if $data->{$_};
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
    if($data->{original_language}){
    	foreach my $lang (@{$data->{original_language}}){
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

    update_related_material($data);

    $data = delete_empty_fields($data);
    if($data->{finalSubmit} and $data->{finalSubmit} eq "recPublish"){
    	$data->{status} = "public";
    }

    my $fixer = Catmandu::Fix->new(fixes => [
        'maybe_add_urn()',
	    'if all_match("status","new") set_field("status","private") end',
        'if all_match("status","returned") set_field("status","private") end',
        ]);

    # citations
    use Citation;
    my $response = Citation::index_citation_update($data,0,'');
    $data->{citation} = $response if $response;

    my $search_bag = Catmandu->store('search')->bag('publication');
    my $backup = Catmandu->store('backup')->bag('publication');

    $fixer->fix($data);

    #compare version!
    my $result = $backup->add($data);
    $search_bag->add($result);
    $search_bag->commit;
    sleep 1;
    return $result; # leave this here to make debugging easier (it doesn't hurt to have it here!)
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

    my $update_rm = update_related_material($del);

    # this will do a hard override of
    # the existing publication
	h->publication->add($del);
	h->publication->commit;

	my $status = delete_file($id);
	sleep 1;

    # delete attached files
#    my $dir = h->config->{upload_dir} ."/$id";
#    my $status = rmdir $dir if -e $dir || 0;
#    croak "Error: could not delete files" if $status;

    # delete citations
#    my $citbag = Catmandu->store('citation')->bag;
#    $citbag->delete($id);
}

1;
