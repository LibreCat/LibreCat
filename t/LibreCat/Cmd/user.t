use strict;
use warnings FATAL => 'all';
use Path::Tiny;
use LibreCat -load => {layer_paths => [qw(t/layer)]};

use Catmandu::Sane;
use Catmandu;

use LibreCat::CLI;
use Test::More;
use Test::Exception;
use App::Cmd::Tester::CaptureExternal;
use Cpanel::JSON::XS;
use Data::Dumper;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Cmd::user';
    use_ok $pkg;
}

require_ok $pkg;

# empty db
Catmandu->store('main')->bag('user')->delete_all;
Catmandu->store('search')->bag('user')->delete_all;

subtest 'missing cmd' => sub {
    my $result = test_app(qq|LibreCat::CLI| => ['user']);
    ok $result->error, 'missing cmd: threw an exception';
};

subtest 'invalid cmd' => sub {
    my $result = test_app(qq|LibreCat::CLI| => ['user', 'do_nonsense']);
    ok $result->error, 'invalid cmd: threw an exception';
    like $result->error, qr/should be one of/, 'error messge for invalid cmd';
};

subtest 'help' => sub {
    my $result = test_app(qq|LibreCat::CLI| => ['help', 'user']);
    ok !$result->error, 'ok threw no exception';

    my $output = $result->stdout;
    like $output, qr/Usage:/, "Help message";
};

subtest 'list empty' => sub {
    my $result = test_app(qq|LibreCat::CLI| => ['user', 'list']);

    ok !$result->error, 'list: ok threw no exception';

    my $output = $result->stdout;
    ok $output , 'list: got an output';

    my $count = count_user($output);

    ok $count == 0, 'list: got no users';
};

subtest 'add invalid' => sub {
    my $result = test_app(
        qq|LibreCat::CLI| => ['user', 'valid', 't/records/invalid-user.yml']);
    ok $result->error, 'validate: threw an exception';

    $result = test_app(
        qq|LibreCat::CLI| => ['user', 'add', 't/records/invalid-user.yml']);
    ok $result->error, 'add invalid user: threw an exception';
};

subtest 'add valid' => sub {
    my $result = test_app(
        qq|LibreCat::CLI| => ['user', 'valid', 't/records/valid-user.yml']);

    ok !$result->error, 'validate: threw no exception';

    $result = test_app(
        qq|LibreCat::CLI| => ['user', 'add', 't/records/valid-user.yml']);

    ok !$result->error, 'add valid user: threw no exception';

    my $output = $result->stdout;
    ok $output , 'add valid user: got an output';

    like $output , qr/^added 999111999/, 'add valid user: id is 99111999';
};

subtest 'get' => sub {
    my $result = test_app(qq|LibreCat::CLI| => ['user', 'get', '999111999']);

    ok !$result->error, 'get: threw no exception';

    my $output = $result->stdout;

    ok $output , 'get: got an output';

    my $importer = Catmandu->importer('YAML', file => \$output);

    my $record = $importer->first;

    is $record->{_id}, '999111999', 'got really a 999111999 record';
    is $record->{email}, 'test.user@physics.com', 'got correct email';
};

subtest 'get via id-file' => sub {
    my $result = test_app(
        qq|LibreCat::CLI| => ['user', 'get', 'file-does-not-exists.yml']);

    ok $result->error, 'throws exception: file does not exist';

    $result = test_app(
        qq|LibreCat::CLI| => ['user', 'get', 't/records/user-ids.txt']);

    ok !$result->error, 'threw no exception';

    ok $result->stdout, 'got an output';
};

subtest 'list' => sub {
    my $result = test_app(qq|LibreCat::CLI| => ['user', 'list']);

    ok !$result->error, 'list: ok threw no exception';

    ok $result->stdout, 'list: got an output';

    ok count_user($result->stdout) == 1, 'list: got no users';

    $result = test_app(qq|LibreCat::CLI| => ['user', 'list', 'id=999111999']);

    ok !$result->error, 'list: ok threw no exception';

    ok $result->stdout, 'list: got an output';

    ok count_user($result->stdout) == 1, 'list: got no users';
};

subtest 'export' => sub {
    my $result = test_app(qq|LibreCat::CLI| => ['user', 'export']);

    ok !$result->error, 'export: threw no exception';

    my $output = $result->stdout;
    ok $output , 'export: got an output';

    like $output , qr/full_name/, 'got user export';

    $result
        = test_app(qq|LibreCat::CLI| => ['user', 'export', 'id=999111999']);

    ok !$result->error, 'export: threw no exception';

    ok $result->stdout, 'export: got an output';
};

subtest 'delete' => sub {
    my $result = test_app(
        qq|LibreCat::CLI| => ['user', 'delete', 'does-not-exist-1234']);

    ok $result->error, "invalid ID";
    like $result->output, qr/ERROR: delete/, 'error message';

    $result = test_app(qq|LibreCat::CLI| => ['user', 'delete', '999111999']);

    ok !$result->error, 'delete: threw no exception';

    ok $result->stdout, 'delete: got an output';

    like $result->stdout, qr/^deleted 999111999/, 'deleted 999111999';
};

subtest 'get non-existent' => sub {
    my $result = test_app(qq|LibreCat::CLI| => ['user', 'get', '999111999']);

    ok $result->error, 'ok no exception';

    my $output = $result->stdout;
    ok length($output) == 0, 'got no result';
};

done_testing;

sub count_user {
    my $str = shift;
    my @lines = grep {!/(^count:|.*\sdeleted\s.*)/} split(/\n/, $str);
    int(@lines);
}
