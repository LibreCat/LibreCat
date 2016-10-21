package LibreCat::Hook::satisfied;

use Catmandu::Sane;
use Moo;

sub fix {
    my ($self, $data) = @_;
    delete $data->{peckish};
    delete $data->{hungry};
    $data->{satisfied} = 1;
}

1;
