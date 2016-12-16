use Catmandu::Sane;
use Path::Tiny;
use lib path(__FILE__)->parent->parent->child('lib')->stringify;
use LibreCat load => (layer_paths => [qw(t/layer)]);
use Catmandu;
use LibreCat::CLI;
use Test::More;
use Test::Exception;
use App::Cmd::Tester;
use Cpanel::JSON::XS;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Cmd::department';
    use_ok $pkg;
}

require_ok $pkg;

# empty db
Catmandu->store('backup')->bag('department')->delete_all;
Catmandu->store('search')->bag('department')->drop;

{
    my $result = test_app(qq|LibreCat::CLI| => ['department']);
    ok $result->error, 'ok threw an exception';
}

{
    my $result = test_app(qq|LibreCat::CLI| => ['department', 'list']);

    ok !$result->error, 'ok threw no exception';

    my $output = $result->stdout;
    ok $output , 'got an output';

    my $count = count_department($output);

    ok $count == 0, 'got no departments';
}

{
    my $result = test_app(qq|LibreCat::CLI| =>
            ['department', 'add', 't/records/invalid-department.yml']);
    ok $result->error, 'ok threw an exception';
}

{
    my $result = test_app(qq|LibreCat::CLI| =>
            ['department', 'add', 't/records/valid-department.yml']);

    ok !$result->error, 'ok threw no exception';

    my $output = $result->stdout;
    ok $output , 'got an output';

    like $output , qr/^added 999000999/, 'added 999000999';
}

{
    my $result
        = test_app(qq|LibreCat::CLI| => ['department', 'get', '999000999']);

    ok !$result->error, 'ok threw no exception';

    my $output = $result->stdout;

    ok $output , 'got an output';

    my $importer = Catmandu->importer('YAML', file => \$output);

    my $record = $importer->first;

    is $record->{_id}, 999000999, 'got really a 999000999 record';
    is $record->{name}, 'Test faculty' , 'got a valid department';
}

{
    my $result = test_app(
        qq|LibreCat::CLI| => ['department', 'delete', '999000999']);

    ok !$result->error, 'ok threw no exception';

    my $output = $result->stdout;
    ok $output , 'got an output';

    like $output , qr/^deleted 999000999/, 'deleted 999000999';
}

{
    my $result
        = test_app(qq|LibreCat::CLI| => ['department', 'get', '999000999']);

    ok $result->error, 'ok no exception';

    my $output = $result->stdout;
    ok length($output) == 0, 'got no result';
}

done_testing;

sub count_department {
    my $str = shift;
    my @lines = grep {!/(^count:|.*\sdeleted\s.*)/} split(/\n/, $str);
    int(@lines);
}
