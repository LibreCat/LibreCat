use strict;
use warnings;
use Test::More;

my $pkg;
BEGIN {
    $pkg = 'LibreCat::Worker::Mailer';
    use_ok $pkg;
}

require_ok $pkg;

done_testing;
