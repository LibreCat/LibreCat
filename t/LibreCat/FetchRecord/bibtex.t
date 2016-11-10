use strict;
use warnings FATAL => 'all';
use Test::More;
use Test::Exception;

use Path::Tiny;
use lib path(__FILE__)->parent->parent->child('lib')->stringify;
use LibreCat qw(:load);

my $pkg;

BEGIN {
    $pkg = 'LibreCat::FetchRecord::bibtex';
    use_ok $pkg;
}

require_ok $pkg;

my $x;

lives_ok { $x = $pkg->new()} 'lives_ok';

can_ok $pkg, $_ for qw(fetch);

{
    my $pub = $x->fetch(<<EOF);
\@book{book,
  author    = {Peter Babington},
  title     = {The title of the work},
  publisher = {The name of the publisher},
  year      = 1993,
  volume    = 4,
  series    = 10,
  address   = {The address},
  edition   = 3,
  month     = 7,
  note      = {An optional note},
  isbn      = {3257227892}
}
EOF

    ok $pub , 'got a publication';

    is $pub->{title} , 'The title of the work' , 'got a title';
    is $pub->{type} , 'book', 'type == book';
}

done_testing;
