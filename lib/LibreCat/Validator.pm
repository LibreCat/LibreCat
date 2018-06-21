package LibreCat::Validator;

use Catmandu::Sane;
use Moo::Role;

with 'Catmandu::Validator';

has whitelist => (is => 'lazy');

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

=head1 SEE ALSO

L<LibreCat>, L<Catmandu::Validator>

=cut
