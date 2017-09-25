use strict;
use warnings FATAL => 'all';
use Test::More;
use Test::Exception;
use LibreCat load => (layer_paths => [qw(t/layer)]);

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Hook::index_record';
    use_ok $pkg;
}
require_ok $pkg;

my $x;
lives_ok {$x = $pkg->new(bag => 'foo')} 'lives_ok';

can_ok $x, 'fix';

done_testing;
