package LibreCat::FileStore::Container;

use Moo::Role;

with 'Catmandu::Logger';

has key        => (is => 'ro' , required => 1);
has created    => (is => 'ro');
has modified   => (is => 'ro');

requires 'list';
requires 'exists';
requires 'add';
requires 'get';
requires 'delete';

1;

__END__
