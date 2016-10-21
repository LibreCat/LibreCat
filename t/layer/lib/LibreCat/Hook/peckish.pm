package LibreCat::Hook::peckish;

use Catmandu::Sane;
use Moo;

sub fix {
    my ($self, $data) = @_;
    $data->{peckish} = 1;
}

1;
