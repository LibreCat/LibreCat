use strict;
use warnings FATAL => 'all';
use Test::More;
use Test::Exception;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Auth::SSO';
    use_ok $pkg;
}
require_ok $pkg;

done_testing;
