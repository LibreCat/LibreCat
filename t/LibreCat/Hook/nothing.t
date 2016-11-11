use strict;
use warnings FATAL => 'all';
use Test::More;
use Test::Exception;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Hook::nothing';
    use_ok $pkg;
}

require_ok $pkg;

my $x;
lives_ok {$x = $pkg->new()} 'lives_ok';

my $res = $x->fix({ foo => 'bar' });

is_deeply $res , { foo => 'bar' } , 'got a hooked result';

done_testing;
