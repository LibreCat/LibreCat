package LibreCat::Validator::JSONSchema;

use Catmandu::Sane;
use Moo;
use namespace::clean;

extends 'Catmandu::Validator::JSONSchema';

with 'LibreCat::Validator';

sub _build_whitelist {
    my ($self) = @_;
    my $properties = $self->schema->{properties} // {};
    [keys %$properties];
}

around last_errors => sub {
    my $orig = shift;
    my $errors = $orig->(@_) // return;
    [map {"$_->{property}: $_->{message}"} @$errors];
};

1;
