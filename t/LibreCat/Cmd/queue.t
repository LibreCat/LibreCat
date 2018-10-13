use strict;
use warnings FATAL => 'all';
use LibreCat -load => {layer_paths => [qw(t/layer)]};
use Test::More;
use Test::Exception;
use App::Cmd::Tester;
use LibreCat::CLI;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Cmd::queue';
    use_ok $pkg;
}
require_ok $pkg;

{
    my $result = test_app(qq|LibreCat::CLI| => ['help', 'queue']);
    ok !$result->error, 'ok threw no exception';

    my $output = $result->stdout;
    like $output, qr/Usage:/, "Help message";
}

SKIP: {

    unless ($ENV{GEARMAN_NETWORK_TEST}) {
        skip("No network. Set GEARMAN_NETWORK_TEST to run these tests.", 5);
    }

    {
        my $result = test_app(qq|LibreCat::CLI| => ['queue']);
        ok $result->error, 'missing cmd: threw an exception';

        my $output = $result->error;
        ok $output, 'got an output';
        like $output, qr/Error/, 'got expected output';
    }

    {
        my $worker = test_app(
            qq|LibreCat::CLI| => [
                'worker', 'indexer', 'start', '--workers', '2', '--supervise'
            ]
        );
        ok $worker, 'can start worker indexer';

        my $result = test_app(qq|LibreCat::CLI| => ['queue', 'status']);
        ok !$result->error, 'status threw no exception';

        my $output = $result->output;
        ok $output, 'got an output';
        like $output, qr/indexer/, 'got expected output';

        $result = test_app(qq|LibreCat::CLI| => ['queue', '--background', 'add_job','indexer', 't/records/job.yml']);
            ok !$result->error, 'add_job threw no exception';

            ok $result->output, 'got an output';
            like $result->output, qr/Adding job/, 'got expected output';

        ok test_app(qq|LibreCat::CLI| =>
                ['worker', 'indexer', 'stop', '--workers', '2', '--supervise']
        ), 'stop workers';
    }

    {
        my $result = test_app(qq|LibreCat::CLI| => ['queue', 'start']);
        ok !$result->error, 'start threw no exception';

        my $output = $result->stdout;
        ok $output, 'got an output';
        like $output, qr/Starting /, 'got expected output';
    }

    {
        my $result = test_app(qq|LibreCat::CLI| => ['queue', 'stop']);
        ok !$result->error, 'stop threw no exception';

        my $output = $result->stdout;
        ok $output, 'got an output';
        like $output, qr/Stopping /, 'got expected output';
    }
}

done_testing;
