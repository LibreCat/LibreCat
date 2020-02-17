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

    package main;

    my $validator = MyValidator->new(
        namespace => "validator.myvalidator.errors",
        schema => { type => "object" }
    );

=head1 namespace

    namespace, used to prefix I18N codes

=head1 errors

Each error must be an object of package L<LibreCat::Validation::Error>

=head1 SEE ALSO

L<LibreCat>, L<Catmandu::Validator>

=cut
