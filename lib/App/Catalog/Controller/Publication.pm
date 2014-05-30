package App::Catalog::Controller::Publication;

use Catmandu::Sane;
use Catmandu;
use App::Catalog::Helper;
use Catmandu::Validator::PUB;
use Hash::Merge qw/merge/;
use Carp;
use Exporter qw/import/;
our @EXPORT
    = qw/new_publication save_publication update_publication edit_publication/;

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
    my $validator = Catmandu::Validator::PUB->new();

    if ( $validator->is_valid($data) ) {
        h->publication->add($data);
        h->publication->commit;
    }
    else {
        croak join(@{$validator->last_errors}, ' | ');
    }

}

sub update_publication {
    my $data = shift;
    croak "Error: No _id specified" unless $data->{_id};

    my $old = h->publication->get( $data->{_id} );
    my $merger = Hash::Merge->new(); 
    #left precedence by default!
    my $new = $merger->merge( $data, $old );

    save_publication($new);
}

sub edit_publication {
    my $id = shift;

    return "Error" unless $id;
    # some pre-processing needed?
    # if not, then this method sub is overkill
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
    my $dir = h->conf->{upload_dir} ."/$id";
    my $status = rmdir $dir if -e $dir || 0;
    croak "Errror: could not delete files" if $status;
}

1;
