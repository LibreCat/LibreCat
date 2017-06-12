use strict;
use warnings FATAL => 'all';
use Test::More;

my $pkg;
my @worker_pkg;

BEGIN {
    $pkg = 'LibreCat::Worker';
    use_ok $pkg;
}

require_ok $pkg;

{
    package T::Worker;
    use Moo;
    with $pkg;

    sub work {
        sleep 0.1;
    }
}

my $worker = T::Worker->new();
ok $worker->does("LibreCat::Worker");

done_testing;
