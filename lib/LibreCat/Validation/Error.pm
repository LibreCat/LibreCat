package LibreCat::Validation::Error;

use Catmandu::Sane;
use Catmandu::Util qw(:is :check);
use Catmandu;
use Catmandu::Error;
use Moo;
use LibreCat::I18N;
use overload q("") => \&to_string, bool => sub {1}, fallback => 1;

has code => (
    is => "ro",
    isa => sub { check_string($_[0]); },
    required => 1
);

has property => (
    is => "ro",
    isa => sub { check_string($_[0]); },
    required => 1
);

has field => (
    is => "ro",
    isa => sub { check_string($_[0]); },
    required => 1
);

has validator => (
    is => "ro",
    isa => sub { check_string($_[0]); },
    required => 1
);

has i18n => (
    is => "ro",
    isa => sub { check_array_ref($_[0]); },
    required => 1
);

sub localize {

    my( $self, $locale ) = @_;

    $locale //= Catmandu->config->{default_lang} || Catmandu::Error->throw(
        "no locale given and no default_lang configured"
    );

    $self->{_i18n} //= {};
    $self->{_i18n}->{$locale} //= LibreCat::I18N->new( locale => $locale );

    $self->{_i18n}->{$locale}->localize(
        @{ $self->i18n() }
    );
}

sub to_string {

    $_[0]->localize();

}

1;

__END__

=pod

=head1 NAME

LibreCat::Validation::Error - class for model validation errors

=head1 SYNOPSIS

    package MyPackage;

    use Catmandu::Sane;
    use LibreCat::Validator::JSONSchema;
    use LibreCat::App::Helper;

    my $publication_validator =
        LibreCat::Validator::JSONSchema->new(schema => h->config->{schemas}{publication});

    unless ($publication_validator->is_valid($rec)) {

        for my $error( @{ $publication_validator->last_errors } ){

            say "error code: " . $error->code;
            say "localized error message: " . $error->localize("en");
            say "json path to affected field: " . $error->property;
            say "short name for affected field: " . $error->field;

        }

    }

=head1 METHODS

=head2 new( code => $code, property => $json_path, field => $field_name, i18n => $array_ref, validator => $package_name )

=head2 code()

returns error code

=head2 property()

returns json path to attribute that contains the invalid value.

e.g. "file.1.access_level"

=head2 field()

returns field name for attribute that contains the invalid value.

e.g. "file.access_level"

=head2 i18n()

returns array ref of arguments for localisation

e.g. ["validator.jsonschema.errors.integer.maximum",4,2]

=head2 validator()

returns package name that generated this object

=head1 SEE ALSO

L<LibreCat>, L<Librecat::Validator>, L<Catmandu::Validator>,
L<Catmandu::Validator::JSONSchema>, L<config/schemas.yml>

=cut
