package LibreCat::FileStore;

use Catmandu::Sane;
use Moo::Role;
use Carp;
use namespace::clean;

with 'Catmandu::Logger';

requires 'list';
requires 'exists';
requires 'add';
requires 'get';
requires 'delete';

1;

__END__
