use Test::Lib;
use TestHeader;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::JobStatus';
    use_ok $pkg;
}

require_ok $pkg;

done_testing;
