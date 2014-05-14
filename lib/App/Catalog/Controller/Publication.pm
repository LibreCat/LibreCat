package App::Catalog::Controller::Publication;

use Catmandu::Sane;
use Catmandu;
use App::Catalog::Helper;
use Catmandu::Validator::PUB;
use Hash::Merge qw/merge/;
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
    return $id;    # correct?
}

sub new_publication {
    return _create_id;
}

sub save_publication {
    my $data      = shift;
    my $validator = Catmandu::Validator::PUB->new(
        handler => sub {
            $data = shift;
            return "error"
                unless $data->{title} =~ m/good title/;    # think, about it
            return;
        }
    );

    if ( $validator->is_valid($data) ) {
        h->publication->add($data);
    }
    else {
        return $validator->last_errors;
    }

}

sub update_publication {
    my $data = shift;
    return "Error: No _id specified" unless $data->{_id};

    my $old = h->publication->get( $data->{_id} );
    my $merger = Hash::Merge->new();           #left precedence by default!
    my $new = $merger->merge( $data, $old );

    save_publication($new);
}

sub edit_publication {
    my $id = shift;

    return "Error" unless $id;
}

sub delete_publication {
	my $id = shift;
	h->publication->delete($id);
	h->publication->commit;
}

1;
