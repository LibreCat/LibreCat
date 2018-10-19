use Catmandu::Sane;
use Path::Tiny;
use LibreCat -load => {layer_paths => [qw(t/layer)]};

use Catmandu::Sane;
use Catmandu;

use LibreCat::CLI;
use Test::More;
use Test::Exception;
use App::Cmd::Tester;
use Cpanel::JSON::XS;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Cmd::research_group';
    use_ok $pkg;
}

require_ok $pkg;

# empty db
Catmandu->store('main')->bag('research_group')->delete_all;
Catmandu->store('search')->bag('research_group')->delete_all;

subtest 'missing cmd' => sub {
    my $result = test_app(qq|LibreCat::CLI| => ['research_group']);
    ok $result->error, 'threw an exception';
};

subtest 'invalid cmd' => sub {
    my $result
        = test_app(qq|LibreCat::CLI| => ['research_group', 'invalid-cmd']);
    ok $result->error, 'threw an exception';
    like $result->error, qr/should be one of/, 'error message';
};

subtest 'help' => sub {
    my $result = test_app(qq|LibreCat::CLI| => ['help', 'research_group']);
    ok !$result->error, 'threw no exception';

    my $output = $result->stdout;
    like $output, qr/Usage:/, "Help message";
};

subtest 'list empty' => sub {
    my $result = test_app(qq|LibreCat::CLI| => ['research_group', 'list']);

    ok !$result->error, 'ok threw no exception';

    my $output = $result->stdout;
    ok $output , 'got an output';

    my $count = count_research_group($output);

    ok $count == 0, 'got no research groups';
};

subtest 'validate' => sub {
    my $result = test_app(
        qq|LibreCat::CLI| => [
            'research_group', 'valid',
            't/records/invalid-research_group.yml'
        ]
    );
    ok $result->error, 'invalid RG: threw an exception';

    $result = test_app(qq|LibreCat::CLI| =>
            ['research_group', 'add', 't/records/valid-research_group.yml']);
    ok !$result->error, 'valid RG: threw no exception';
};

subtest 'add invalid' => sub {
    my $result
        = test_app(qq|LibreCat::CLI| =>
            ['research_group', 'add', 't/records/invalid-research_group.yml']
        );
    ok $result->error, 'add invalid RG: threw an exception';
};

subtest 'add valid' => sub {
    my $result = test_app(qq|LibreCat::CLI| =>
            ['research_group', 'add', 't/records/valid-research_group.yml']);

    ok !$result->error, 'add valid RG: threw no exception';

    my $output = $result->stdout;
    ok $output , 'add: got an output';

    like $output , qr/^added RG999000999/, 'added RG999000999';
};

subtest 'list' => sub {
    my $result = test_app(qq|LibreCat::CLI| => ['research_group', 'list']);

    ok !$result->error, 'list';

    my $output = $result->stdout;
    ok $output, 'list: got an output';

    my $count = count_research_group($output);

    ok $count > 0, 'got more than one research_group';

    $result = test_app(
        qq|LibreCat::CLI| => ['research_group', 'list', 'id=RG999000999']);

    ok !$result->error, 'list w. query';

    $output = $result->stdout;
    ok $output, 'w. query: got an output';

    ok count_research_group($output) == 1, 'got one RG record';
};

subtest 'get' => sub {
    my $result = test_app(
        qq|LibreCat::CLI| => ['research_group', 'get', 'RG999000999']);

    ok !$result->error, 'ok threw no exception';

    my $output = $result->stdout;

    ok $output , 'got an output';

    my $importer = Catmandu->importer('YAML', file => \$output);

    my $record = $importer->first;

    is $record->{_id},  'RG999000999', 'got really a RG999000999 record';
    is $record->{name}, 'TestGroup',   'got a valid name';
};

subtest 'get via id-file' => sub {
    my $result = test_app(qq|LibreCat::CLI| =>
            ['research_group', 'get', 't/records/research_group-ids.txt']);

    ok !$result->error, 'threw no exception';

    my $output = $result->stdout;

    ok $output , 'got an output';
};

subtest 'export' => sub {
    my $result = test_app(qq|LibreCat::CLI| => ['research_group', 'export']);

    ok !$result->error, 'threw no exception';

    my $output = $result->stdout;

    ok $output , 'got an output';

    like $output, qr/_id: RG999000999/, 'correct output';

    $result = test_app(
        qq|LibreCat::CLI| => ['research_group', 'export', 'id=RG999000999']);

    ok !$result->error, 'threw no exception';

    $output = $result->stdout;

    ok $output , 'got an output w. query';

    like $output, qr/_id: RG999000999/, 'correct output w. query';
};

subtest 'delete' => sub {
    my $result = test_app(qq|LibreCat::CLI| =>
            ['research_group', 'delete', 'does-not-exist-1234']);

    ok $result->error, 'threw exception: ID does not exit';

    like $result->output, qr/ERROR: delete/, 'error mesage';

    $result = test_app(
        qq|LibreCat::CLI| => ['research_group', 'delete', 'RG999000999']);

    ok !$result->error, 'ok threw no exception';

    my $output = $result->stdout;
    ok $output , 'got an output';

    like $output , qr/^deleted RG999000999/, 'deleted RG999000999';
};

subtest 'get deleted record' => sub {
    my $result = test_app(
        qq|LibreCat::CLI| => ['research_group', 'get', 'RG999000999']);

    ok $result->error, 'ok no exception';

    my $output = $result->stdout;
    ok length($output) == 0, 'got no result';
};

done_testing;

sub count_research_group {
    my $str = shift;
    my @lines = grep {!/(^count:|.*\sdeleted\s.*)/} split(/\n/, $str);
    int(@lines);
}
