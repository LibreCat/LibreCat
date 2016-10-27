package LibreCat::Rule::own;

use Catmandu::Sane;
use Moo;
use namespace::clean;

with 'LibreCat::Rule';

sub test {
    my ($self, $subject, $object) = @_;

    $object->{creator} && $object->{creator}{login} eq $subject->{_id};
}

1;
