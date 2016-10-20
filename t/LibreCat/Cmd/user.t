BEGIN {
    use Catmandu::Sane;
    use Path::Tiny;
    use lib path(__FILE__)->parent->parent->child('lib')->stringify;
    use LibreCat::Layers;

    LibreCat::Layers->new(layer_paths => [qw(t/layer)])->load;
}

use Catmandu::Sane;
use Catmandu;

use LibreCat::CLI;
use Test::More;
use Test::Exception;
use App::Cmd::Tester::CaptureExternal;
use Cpanel::JSON::XS;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Cmd::user';
    use_ok $pkg;
}

require_ok $pkg;

# empty db
Catmandu->store('backup')->bag('researcher')->delete_all;
Catmandu->store('search')->bag('researcher')->drop;

{
    my $result = test_app(qq|LibreCat::CLI| => ['user']);
    ok $result->error, 'ok threw an exception';
}

{
    my $result = test_app(qq|LibreCat::CLI| => ['user', 'list']);

    ok !$result->error, 'ok threw no exception';

    my $output = $result->stdout;
    ok $output , 'got an output';

    my $count = count_user($output);

    ok $count == 0, 'got no users';
}

{
    my $result = test_app(
        qq|LibreCat::CLI| => ['user', 'add', 't/records/invalid-user.yml']);
    ok $result->error, 'ok threw an exception';
}

{
    my $result = test_app(
        qq|LibreCat::CLI| => ['user', 'add', 't/records/valid-user.yml']);

    ok !$result->error, 'ok threw no exception';

    my $output = $result->stdout;
    ok $output , 'got an output';

    like $output , qr/^added 999111999/, 'added 999111999';
}

{
    my $result = test_app(qq|LibreCat::CLI| => ['user', 'get', '999111999']);

    ok !$result->error, 'ok threw no exception';

    my $output = $result->stdout;

    ok $output , 'got an output';

    my $importer = Catmandu->importer('YAML', file => \$output);

    my $record = $importer->first;

    is $record->{_id}, '999111999', 'got really a 999111999 record';
}

{
    my $result
        = test_app(qq|LibreCat::CLI| => ['user', 'delete', '999111999']);

    ok !$result->error, 'ok threw no exception';

    my $output = $result->stdout;
    ok $output , 'got an output';

    like $output , qr/^deleted 999111999/, 'deleted 999111999';
}

{
    my $result = test_app(qq|LibreCat::CLI| => ['user', 'get', '999111999']);

    ok $result->error, 'ok no exception';

    my $output = $result->stdout;
    ok length($output) == 0, 'got no result';
}

done_testing;

sub count_user {
    my $str = shift;
    my @lines = grep {!/(^count:|.*\sdeleted\s.*)/} split(/\n/, $str);
    int(@lines);
}
