use Catmandu;
use warnings FATAL => 'all';
use LibreCat::JobQueue;
use Test::More;
use Test::Exception;
use Role::Tiny;

my $pkg;

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

    package T::WorkerCustomFunctions;
    use Moo;
    with $pkg;

    sub worker_functions {
        ['drink', {'have_hangover' => 'do_have_hangover'}];
    }

    sub drink {
        sleep 0.1;
    }

    sub do_have_hangover {
        sleep 0.2;
    }
}


{
    my $worker = T::Worker->new();
    ok $worker->does("LibreCat::Worker");

    can_ok $worker, 'work';
}

{
    my $worker = T::WorkerCustomFunctions->new();
    ok $worker->does("LibreCat::Worker");

    my $queue = LibreCat::JobQueue->new();
    ok $queue->add_job('drink', {beverage => 'water'});

    ok $queue->add_job('have_hangover', {beverage => 'beer'});
}

done_testing;
