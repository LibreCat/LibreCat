package LibreCat::Validator;

use Catmandu::Sane;
use Catmandu::Util qw(check_string);
use Moo::Role;

with 'Catmandu::Validator';

has whitelist => (is => 'lazy');

has namespace => (
    is => "ro",
    required => 1,
    isa => sub { check_string($_[0]); }
);

sub _build_whitelist {
    [];
}

1;

__END__

=pod

=head1 NAME

LibreCat::Validator - a base class for validators

=head1 SYNOPSIS

    package MyValidator;

    use Moo;

    with "LibreCat::Validator";

    sub _build_whitelist {
        return ["author", "title", "year"];
    }

=head1 namespace

    namespace, used to prefix I18N codes

=head1 errors

Each error must be an object that has the following keys:

    * code:

        * type: string

        * description: error code

    * property:

        * type: string

        * description: json path to the thing that caused the error

        e.g. file.0.access_level

    * field:

        * type: string

        * description: field name. Simplified version of property, so without index in its path.

        e.g. file.access_level

    * i18n:

        * type: array reference

        * description: list of arguments for localisation, typically the i18n key, followed by its arguments.

    * message:

        * type: string

        * description: internal description of the error

    * validator:

        * type: string

        * description: name of the validator.

=head1 SEE ALSO

L<LibreCat>, L<Catmandu::Validator>

=cut
