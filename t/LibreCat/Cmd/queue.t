use strict;
use warnings FATAL => 'all';
use LibreCat load => (layer_paths => [qw(t/layer)]);
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

SKIP: {

    unless ($ENV{GEARMAN_NETWORK_TEST}) {
        skip("No network. Set GEARMAN_NETWORK_TEST to run these tests.", 5);
    }

    {
        my $result = test_app(qq|LibreCat::CLI| => ['queue']);
        ok $result->error, 'ok threw an exception';

        my $output = $result->error;
        ok $output, 'got an output';
        like $output, qr/Error/, 'got expected output';
    }

    {
        my $worker = test_app(
            qq|LibreCat::CLI| => [
                'worker', 'mailer', 'start', '--workers', '2', '--supervise'
            ]
        );

        my $result = test_app(qq|LibreCat::CLI| => ['queue','status']);
        ok !$result->error, 'ok threw no exception';

        my $output = $result->stdout;
        ok $output, 'got an output';
        like $output, qr/mailer/, 'got expected output';

        ok test_app(qq|LibreCat::CLI| =>
                ['worker', 'mailer', 'stop', '--workers', '2', '--supervise']
        ), 'stop workers';
    }

    {
        my $result = test_app(qq|LibreCat::CLI| => ['queue', 'start']);
        ok !$result->error, 'ok threw no exception';

        my $output = $result->stdout;
        ok $output, 'got an output';
        like $output, qr/Starting /, 'got expected output';
    }

    {
        my $result = test_app(qq|LibreCat::CLI| => ['queue', 'stop']);
        ok !$result->error, 'ok threw no exception';

        my $output = $result->stdout;
        ok $output, 'got an output';
        like $output, qr/Stopping /, 'got expected output';
    }

}
done_testing
