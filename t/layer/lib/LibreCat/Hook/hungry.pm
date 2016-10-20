package LibreCat::Hook::hungry;

use Catmandu::Sane;
use Moo;

sub fix {
    my ($self, $data) = @_;
    $data->{hungry} = 1;
}

1;
