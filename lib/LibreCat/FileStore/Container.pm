package LibreCat::FileStore::Container;

use Moo::Role;

with 'Catmandu::Logger';

has key        => (is => 'ro' , required => 1);
has created    => (is => 'ro');
has modified   => (is => 'ro');

1;

__END__

=pod

=head1 NAME

LibreCat::FileStore::Container - metadata description of a file store container

=head1 SYNOPSIS

   use LibreCat::FileStore;

   my $store = LibreCat::FileStore->new();

   $store->add(LibreCat::FileStore::Container->new(key => '1234'));

=cut
