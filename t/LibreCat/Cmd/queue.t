use strict;
use warnings FATAL => 'all';
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
    my $result = test_app(qq|LibreCat::CLI| => ['queue']);
    ok ! $result->error, 'ok threw no exception';

    my $output = $result->stdout;
    ok $output, 'got an output';
    like $output, qr/functions/, 'got expected output';
}

{
    my $worker = test_app(qq|LibreCat::CLI| =>
        ['worker', 'mailer', 'start', '--workers', '2', '--supervise']);

    my $result = test_app(qq|LibreCat::CLI| => ['queue']);
    ok ! $result->error, 'ok threw no exception';

    my $output = $result->stdout;
    ok $output, 'got an output';
    like $output, qr/mailer/, 'got expected output';

    ok test_app(qq|LibreCat::CLI| =>
        ['worker', 'mailer', 'stop', '--workers', '2', '--supervise']),
        'stop workers';
}

done_testing
