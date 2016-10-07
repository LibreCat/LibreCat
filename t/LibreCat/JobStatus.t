use strict;
use warnings FATAL => 'all';
use Test::More;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::JobStatus';
    use_ok $pkg;
}

require_ok $pkg;

done_testing;
