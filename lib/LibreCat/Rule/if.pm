package LibreCat::Rule::if;

use Catmandu::Sane;
use Catmandu::Util qw(is_value);
use Moo;
use namespace::clean;

with 'LibreCat::Rule';

has key => (is => 'lazy');
has val => (is => 'lazy');

sub _build_key {
    my ($self) = @_;
    $self->args->[0] // '_id';
}

sub _build_val {
    my ($self) = @_;
    $self->args->[1];
}

sub test {
    my ($self, $subject, $object) = @_;
    my $key = $self->key;
    my $val = $self->val;
    if (defined $val) {
        is_value($object->{$key}) && $object->{$key} eq $val;
    } else {
        is_value($object->{$key}) && $object->{$key};
    }
}

1;

