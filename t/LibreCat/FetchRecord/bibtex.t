use strict;
use warnings FATAL => 'all';
use Test::More;
use Test::Exception;
use LibreCat load => (layer_paths => [qw(t/layer)]);
use Data::Dumper;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::FetchRecord::bibtex';
    use_ok $pkg;
}

require_ok $pkg;

my $x;

lives_ok { $x = $pkg->new()} 'lives_ok';

can_ok $pkg, $_ for qw(fetch);

subtest 'one_rec' => sub {
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
};

subtest 'more_recs' => sub {
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

\@book{book,
  author    = {Peter Junior},
  title     = {The title of the second item},
  publisher = {The name of the publisher},
  year      = 1883,
  volume    = 4,
  series    = 10,
  address   = {The address},
  edition   = 3,
  month     = 7,
  note      = {An optional note},
  isbn      = {3257227892}
}
EOF

    ok $pub;
note Dumper $pub;
    ok $pub->[0];
    ok $pub->[1];

    is $pub->[0]->{author}, 'Peter Babington', "first author";

    is $pub->[1]->{title}, 'The title of the second item', 'second title';
};

done_testing;
