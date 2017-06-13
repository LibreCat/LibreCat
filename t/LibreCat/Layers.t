use strict;
use warnings FATAL => 'all';
use Test::More;
use Test::Exception;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Layers';
    use_ok $pkg;
}

require_ok $pkg;

lives_ok {$pkg->new()} 'lives_ok';

ok $pkg->new->config;

done_testing;
