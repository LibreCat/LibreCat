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
    my $orig   = shift;
    my $errors = $orig->(@_) // return;
    [
      map {
        sprintf "%s: %s"
            , $_->{property} // '<null>'
            , $_->{message}  // '<null>'
      } @$errors
    ];
};

1;

__END__

=pod

=head1 NAME

LibreCat::Validator::JSONSchema - a JSONSchema validator

=head1 SYNOPSIS

    package MyPackage;

    use LibreCat::Validator::JSONSchema;
    use LibreCat::App::Helper;

    my $publication_validator =
        LibreCat::Validator::JSONSchema->new(schema => h->config->{schemas}{publication});

    if ($publication_validator->is_valid($rec)) {
        # ...
    }

=head1 SEE ALSO

L<LibreCat>, L<Librecat::Validator>, L<Catmandu::Validator>,
L<Catmandu::Validator::JSONSchema>, L<config/schemas.yml>

=cut
