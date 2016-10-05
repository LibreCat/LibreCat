use Test::Lib;
use TestHeader;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Layers';
    use_ok $pkg;
}

require_ok $pkg;

lives_ok {$pkg->new()} 'lives_ok';

done_testing;
