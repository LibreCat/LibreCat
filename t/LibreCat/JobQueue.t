use strict;
use warnings FATAL => 'all';
use Test::More;
use Test::Exception;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::JobQueue';
    use_ok $pkg;
}

require_ok $pkg;

lives_ok {$pkg->new()} 'lives_ok';

can_ok $pkg, $_ for qw(add_job job_status);

{

    package T::Worker::Mock;

    sub do_work {
        sleep 2;
    }

}

my $q = $pkg->new;

my $job_id = $q->add_job("mock", {hello => "world"});
ok $job_id;

my $status = $q->job_status($job_id);
ok $status;

done_testing;
