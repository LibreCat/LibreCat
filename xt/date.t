use strict;
use warnings;
use Test::More;

use DateTime;

my $dt= DateTime->now();
my $date = $dt->add(days => 1)->ymd;
ok ($date eq "2014-07-30", "date ok");

done_testing;
