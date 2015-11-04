package LibreCat::FileStore;

use Catmandu::Sane;
use Moo::Role;
use namespace::clean;

with 'Catmandu::Logger';
#with 'Catmandu::Iterable';

requires 'list';
requires 'info';
requires 'add';
requires 'get';
requires 'delete';

1;

__END__
