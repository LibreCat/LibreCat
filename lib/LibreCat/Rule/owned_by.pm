package LibreCat::Rule::owned_by;

use Catmandu::Sane;
use Moo;

with 'LibreCat::Rule';

sub test {
    my ($self, $subject, $object, $param) = @_;

    $object->{creator} && $object->{creator}{login} eq $param;
}

1;
