package LibreCat::Rule::owned_by;

use Catmandu::Sane;
use Moo;
use namespace::clean;

with 'LibreCat::Rule';

has key => (is => 'lazy');

sub _build_key {
    my ($self) = @_;
    $self->args->[0] // 'login';
}

sub test {
    my ($self, $subject, $object, $params) = @_;

    $object->{creator} && $object->{creator}{login} eq $params->{$self->key};
}

1;
