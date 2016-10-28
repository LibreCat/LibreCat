use strict;
use warnings FATAL => 'all';
use Test::More;
use Test::Exception;
use App::Cmd::Tester;
use LibreCat::CLI;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Cmd::worker';
    use_ok $pkg;
}

require_ok $pkg;

{
    my $result = test_app(qq|LibreCat::CLI| => ['worker']);

    ok $result->error, 'ok threw an exception';
    like $result->error, qr/should be one of/, 'got expected output';
}

{
    for my $cmd (qw(start stop restart status)) {
        my $result = test_app(qq|LibreCat::CLI| => ['worker', $cmd]);

        ok $result->error, 'ok threw an exception';
        like $result->error, qr/worker name missing/, 'got expected output';
    }
}

{
    my $result = test_app(qq|LibreCat::CLI| =>
        ['worker', 'mailer', 'start', '--workers', '2', '--supervise']);

    ok ! $result->error, 'ok threw no exception at start';
    like $result->stdout, qr/starting daemon.*mailer/, 'starting worker';

    $result = test_app(qq|LibreCat::CLI| =>
        ['worker', 'mailer', 'restart', '--workers', '2', '--supervise']);

    ok ! $result->error, 'ok threw no exception at restart';
    like $result->stdout, qr/stopping/, 'restarting worker: stop';
    like $result->stdout, qr/starting/, 'restarting worker: start';

    $result = test_app(qq|LibreCat::CLI| =>
        ['worker', 'mailer', 'status']);

    ok ! $result->error, 'ok threw no exception at status';
    like $result->stdout, qr/librecat-cmd-worker-mailer/, 'status of worker';


    $result = test_app(qq|LibreCat::CLI| =>
        ['worker', 'mailer', 'stop', '--workers', '2', '--supervise']);

    ok ! $result->error, 'ok threw no exception at stop';
    like $result->stdout, qr/stopping.*mailer/, 'stopping worker'
}

done_testing;
