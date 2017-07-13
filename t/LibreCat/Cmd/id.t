use strict;
use warnings FATAL => 'all';
use Path::Tiny;
use LibreCat load => (layer_paths => [qw(t/layer)]);

use Catmandu;

use LibreCat::CLI;
use Test::More;
use Test::Exception;
use App::Cmd::Tester;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Cmd::project';
    use_ok $pkg;
}

require_ok $pkg;

# empty db
Catmandu->store('backup')->bag('info')->delete_all;
Catmandu->store('search')->bag('info')->delete_all;

subtest 'id without cmd' => sub {
    my $result = test_app(qq|LibreCat::CLI| => ['id']);
    ok $result->error, 'ok threw an exception';
    like $result->error, qr/should be one of/, 'error message';

    $result = test_app(qq|LibreCat::CLI| => ['id', 'boom']);
    ok $result->error, 'ok threw an exception';
    like $result->error, qr/should be one of/, 'error message';
};

subtest 'id get' => sub {
    my $result = test_app(qq|LibreCat::CLI| => ['id', 'get']);
    ok !$result->error, 'ok threw no exception';
    ok $result->output, 'got an output';
    like $result->output, qr/\d+/, 'output looks good';
};

subtest 'id set' => sub {
    my $result = test_app(qq|LibreCat::CLI| => ['id', 'set', '100']);
    ok !$result->error, 'ok threw no exception';
    ok $result->output, 'got an output';
    like $result->output, qr/\d+/, 'output looks good';

    $result = test_app(qq|LibreCat::CLI| => ['id', 'get']);
    like $result->output, qr/100/, 'ID setted correctly';
};

done_testing;
