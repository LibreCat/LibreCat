package LibreCat::Types;

use Catmandu::Sane;
use Types::Standard qw(CycleTuple Str Any);
use Type::Utils -all;
use Type::Library
   -base,
   -declare => qw(Pairs);

declare Pairs, as CycleTuple[Str, Any], where { scalar(@$_) % 2 == 0 };

1;

__END__

=pod

=head1 NAME

LibreCat::Types - LibreCat custom types library

=head1 SYNOPSIS

    

=head1 TYPES

    use LibreCat::Types qw(+Pairs);

=head2 Pairs

An even sized ArrayRef of Str => Any pairs.

    [foo => Foo->new, bar => 'bar']

=head1 SEE ALSO

L<Type::Library>

=cut
