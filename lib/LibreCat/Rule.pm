package LibreCat::Rule;

use Catmandu::Sane;
use Moo::Role;

has args => (is => 'ro', default => sub {[]});

requires 'test';

1;
