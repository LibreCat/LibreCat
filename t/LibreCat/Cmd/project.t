use Catmandu::Sane;
use Path::Tiny;
use LibreCat -load => {layer_paths => [qw(t/layer)]};
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
Catmandu->store('main')->bag('project')->delete_all;
Catmandu->store('search')->bag('project')->delete_all;

subtest 'missing cmd' => sub {
    my $result = test_app(qq|LibreCat::CLI| => ['project']);
    ok $result->error,   'ok threw an exception';
    like $result->error, qr/should be one of/,
        'error message for missing command';
};

subtest 'missing cmd' => sub {
    my $result = test_app(qq|LibreCat::CLI| => ['project', 'do_nonsense']);
    ok $result->error,   'ok threw an exception';
    like $result->error, qr/should be one of/,
        'error message for invalid command';
};

subtest 'help' => sub {
    my $result = test_app(qq|LibreCat::CLI| => ['help', 'project']);
    ok !$result->error, 'ok threw no exception';

    my $output = $result->stdout;
    like $output, qr/Usage:/, "Help message";
};

subtest 'list' => sub {
    my $result = test_app(qq|LibreCat::CLI| => ['project', 'list']);

    ok !$result->error, 'ok list: threw no exception';

    my $output = $result->stdout;
    ok $output , 'got an output for list';

    my $count = count_project($output);

    ok $count == 0, 'got no projects';
};

subtest 'validate' => sub {
    my $result = test_app(qq|LibreCat::CLI| =>
            ['project', 'valid', 't/records/invalid-project.yml']);
    ok $result->error, "file not valid";
    like $result->output, qr/^ERROR/, "output for not valid file";

    $result = test_app(qq|LibreCat::CLI| =>
            ['project', 'valid', 't/records/valid-project.yml']);
    ok !$result->error, "file valid";
    unlike $result->output, qr/^ERROR/, "output for valid file";
};

subtest 'add non-existent file' => sub {
    my $result = test_app(qq|LibreCat::CLI| => ['project', 'add']);
    ok $result->error, 'missing file: threw an exception';

    $result = test_app(qq|LibreCat::CLI| =>
            ['project', 'add', 't/records/does-not-exist.yml']);
    ok $result->error, 'non-existent file: threw an exception';
};

subtest 'add invalid project' => sub {
    my $result = test_app(qq|LibreCat::CLI| =>
            ['project', 'add', 't/records/invalid-project.yml']);
    ok $result->error, 'invalid project: threw an exception';
};

subtest 'add valid project' => sub {
    my $result = test_app(qq|LibreCat::CLI| =>
            ['project', 'add', 't/records/valid-project.yml']);

    ok !$result->error, 'valid project: threw no exception';

    my $output = $result->stdout;
    ok $output , 'got an output';

    like $output , qr/^added P9999999/, 'added P9999999';
};

subtest 'get without ID' => sub {
    my $result = test_app(qq|LibreCat::CLI| => ['project', 'get']);

    ok $result->error, 'missing ID: threw no exception';

    like $result->error, qr/usage:/, 'error message for missing ID';
};

subtest 'get project' => sub {
    my $result
        = test_app(qq|LibreCat::CLI| => ['project', 'get', 'P9999999']);

    ok !$result->error, 'ok threw no exception';

    my $output = $result->stdout;

    ok $output , 'got an output';

    my $importer = Catmandu->importer('YAML', file => \$output);

    my $record = $importer->first;

    is $record->{_id}, 'P9999999', 'got really a P9999999 record';
    is $record->{description}, 'Librecat project. What else?',
        'got a valid description';
};

subtest 'list w. query' => sub {
    my $result
        = test_app(qq|LibreCat::CLI| => ['project', 'list', 'id=P9999999']);

    ok !$result->error, 'threw no exception';

    my $output = $result->stdout;
    ok $output , 'got an output for list';

    my $count = count_project($output);

    ok $count == 1, 'got 1 project';
};

subtest 'get project via id file' => sub {
    my $result = test_app(
        qq|LibreCat::CLI| => ['project', 'get', 't/records/project-ids.txt']);

    ok !$result->error, 'ok threw no exception';

    my $output = $result->stdout;

    ok $output , 'got an output';
};

subtest 'export project' => sub {
    my $result = test_app(qq|LibreCat::CLI| => ['project', 'export']);

    ok !$result->error, "threw no exception";
    like $result->output, qr/_id:/, "export output";

    $result
        = test_app(qq|LibreCat::CLI| => ['project', 'export', 'id=P9999999']);

    ok !$result->error, "threw no exception";
    like $result->output, qr/P9999999/, "export output";
};

subtest 'delete project' => sub {
    my $result = test_app(qq|LibreCat::CLI| => ['project', 'delete']);

    ok $result->error, 'missing ID: threw an exception';

    $result
        = test_app(qq|LibreCat::CLI| => ['project', 'delete', '123INVALID']);

    ok $result->error, 'invalid ID: threw an exception';

    like $result->output, qr/ERROR: delete/, "error message for invalid ID";

    $result
        = test_app(qq|LibreCat::CLI| => ['project', 'delete', 'P9999999']);

    ok !$result->error, 'ok threw no exception';

    my $output = $result->stdout;
    ok $output , 'got an output';

    like $output , qr/^deleted P9999999/, 'deleted P9999999';

    $result = test_app(qq|LibreCat::CLI| => ['project', 'get', 'P9999999']);

    ok $result->error, 'ok no exception';

    $output = $result->stdout;
    ok length($output) == 0, 'got no result';
};

done_testing;

sub count_project {
    my $str = shift;
    my @lines = grep {!/(^count:|.*\sdeleted\s.*)/} split(/\n/, $str);
    int(@lines);
}
