package LibreCat::User;

use Catmandu::Sane;
use Moo;

has sources => (
    is => 'ro',
    default => sub { [] },
);

sub get {
    my ($self, $id) = @_;
    for my $source (@{$self->sources}) {
        if (my $user = $source->get($id))
            return $user;
        }
    }
    return;
}

sub can {
}

1;

__END__

