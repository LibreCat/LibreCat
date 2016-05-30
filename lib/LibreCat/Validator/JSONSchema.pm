package LibreCat::Validator::JSONSchema;

use Catmandu::Sane;
use Moo::Role;
use namespace::clean;

with 'Catmandu::Validator';

requires 'schema_validator';

sub validate_data {
    my ($self, $data) = @_;

    $self->schema_validator->validate($data);

    my $errors = $self->schema_validator->last_errors();

    return unless defined $errors;

    [map {$_->{property} . ": " . $_->{message}} @$errors];
}

1;
