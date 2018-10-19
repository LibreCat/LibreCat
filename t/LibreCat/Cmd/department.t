use strict;
use warnings FATAL => 'all';
use Path::Tiny;
use LibreCat -load => {layer_paths => [qw(t/layer)]};
use Catmandu;
use LibreCat::CLI;
use Test::More;
use Test::Exception;
use App::Cmd::Tester;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Cmd::department';
    use_ok $pkg;
}

require_ok $pkg;

# empty db
Catmandu->store('main')->bag('department')->delete_all;
Catmandu->store('search')->bag('department')->delete_all;
Catmandu->store('main')->bag('department_version')->delete_all;

subtest 'initial cmd' => sub {
    my $result = test_app(qq|LibreCat::CLI| => ['department']);
    ok $result->error, 'missing command: threw an exception';
};

subtest 'invalid cmd' => sub {
    my $result = test_app(qq|LibreCat::CLI| => ['department', 'do_nonsense']);
    ok $result->error,   'missing command: threw an exception';
    like $result->error, qr/should be one of/,
        "error message for invalid command";
};

subtest 'help' => sub {
    my $result = test_app(qq|LibreCat::CLI| => ['help', 'department']);
    ok !$result->error, 'ok threw no exception';

    my $output = $result->stdout;
    like $output, qr/Usage:/, "Help message";
};

subtest 'list empty' => sub {
    my $result = test_app(qq|LibreCat::CLI| => ['department', 'list']);

    ok !$result->error, 'list: threw no exception';

    my $output = $result->stdout;
    ok $output , 'list departments: got an output';

    my $count = count_department($output);

    ok $count == 0, 'list departments: empty';
};

subtest 'validate' => sub {
    my $result = test_app(qq|LibreCat::CLI| =>
            ['department', 'valid', 't/records/invalid-department.yml']);

    ok $result->error, "file not valid";
    like $result->output, qr/^ERROR/, "output for not valid file";

    $result = test_app(qq|LibreCat::CLI| =>
            ['department', 'valid', 't/records/valid-department.yml']);
    ok !$result->error, "file valid";
    unlike $result->output, qr/^ERROR/, "output for valid file";
};

subtest 'add invalid' => sub {
    my $result = test_app(qq|LibreCat::CLI| =>
            ['department', 'add', 't/records/invalid-department.yml']);
    ok $result->error, 'add invalid department: threw an exception';
};

subtest 'add valid' => sub {
    my $result = test_app(qq|LibreCat::CLI| =>
            ['department', 'add', 't/records/valid-department.yml']);

    ok !$result->error, 'add valid department: threw no exception';

    my $output = $result->stdout;
    ok $output , 'got an output';

    like $output , qr/^added 999000999/, 'added 999000999';

    my $stored_record
        = Catmandu->store('main')->bag('department')->get('999000999');
    is $stored_record->{_id}, '999000999', 'stored record id';

    my $indexed_record
        = Catmandu->store('search')->bag('department')->get('999000999');
    is $indexed_record->{_id}, '999000999', 'indexed record id';
};

subtest 'get' => sub {
    my $result
        = test_app(qq|LibreCat::CLI| => ['department', 'get', '999000999']);

    ok !$result->error, 'ok threw no exception';

    my $output = $result->stdout;

    ok $output , 'got an output';

    my $importer = Catmandu->importer('YAML', file => \$output);

    my $record = $importer->first;

    is $record->{_id},  999000999,      'got really a 999000999 record';
    is $record->{name}, 'Test faculty', 'got a valid department';
};

subtest 'get via id_file' => sub {
    my $result = test_app(qq|LibreCat::CLI| =>
            ['department', 'get', 't/records/department_ids.txt']);

    ok !$result->error, 'ok threw no exception';

    my $output = $result->stdout;

    ok $output , 'got an output';

    my $importer = Catmandu->importer('YAML', file => \$output);

    my $record = $importer->first;

    is $record->{_id},  999000999,      'got really a 999000999 record';
    is $record->{name}, 'Test faculty', 'got a valid department';
};

subtest 'list with options' => sub {
    my $result = test_app(qq|LibreCat::CLI| => ['department', 'list']);

    ok !$result->error, 'list: threw no exception';

    my $output = $result->stdout;
    ok $output , 'list departments: got an output';

    my $count = count_department($output);

    ok $count > 0, 'got some departments';

    $result = test_app(
        qq|LibreCat::CLI| => ['department', 'list', 'name=relativity']);

    ok !$result->error, 'list: threw no exception';
    $output = $result->stdout;
    count_department($output) == 1, "got one department";
};

subtest 'tree' => sub {
    my $result = test_app(qq|LibreCat::CLI| => ['department', 'tree']);

    ok !$result->error, "threw no exception";
    like $result->output, qr/tree:/, "tree ouput";
};

subtest 'export' => sub {
    my $result = test_app(qq|LibreCat::CLI| => ['department', 'export']);

    ok !$result->error, "threw no exception";
    like $result->output, qr/_id:/, "export output";

    $result = test_app(
        qq|LibreCat::CLI| => ['department', 'export', 'name=relativity']);

    ok !$result->error, "threw no exception";

    count_department($result->output) == 1, "got one department";
};

subtest 'delete' => sub {
    my $result = test_app(
        qq|LibreCat::CLI| => ['department', 'delete', '999000999']);

    ok !$result->error, 'ok threw no exception';

    my $output = $result->stdout;
    ok $output , 'got an output';

    like $output , qr/^deleted 999000999/, 'deleted 999000999';

    $result
        = test_app(qq|LibreCat::CLI| => ['department', 'get', '999000999']);

    ok $result->error, 'ok no exception';

    $output = $result->stdout;
    ok length($output) == 0, 'got no result';

    $result = test_app(qq|LibreCat::CLI| =>
            ['department', 'delete', 'does-not-exist-123434']);

    ok $result->error, 'throw exception: delete invalid id';
    like $result->output, qr/ERROR: delete/, 'error message delete failed';
};

subtest 'tree with file' => sub {
    my $result = test_app(qq|LibreCat::CLI| =>
            ['department', 'tree', 't/records/department-tree.yml']);

    ok !$result->error, "threw no exception";
    ok $result->output;
    like $result->output, qr/added \d+/, "add tree via file";
};

done_testing;

sub count_department {
    my $str = shift;
    my @lines = grep {!/(^count:|.*\sdeleted\s.*)/} split(/\n/, $str);
    int(@lines);
}
