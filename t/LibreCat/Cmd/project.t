BEGIN {
    use Catmandu::Sane;
    use Path::Tiny;
    use lib path(__FILE__)->parent->parent->child('lib')->stringify;
    use LibreCat::Layers;

    LibreCat::Layers->new(layer_paths => [qw(t/layer)])->load;
}

use strict;
use warnings;
use Catmandu::Sane;
use Catmandu;

use LibreCat::CLI;
use Test::More;
use Test::Exception;
use App::Cmd::Tester;
use Cpanel::JSON::XS;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Cmd::project';
    use_ok $pkg;
}

require_ok $pkg;

# empty db
Catmandu->store('backup')->bag('project')->delete_all;
Catmandu->store('search')->bag('project')->drop;

{
    my $result = test_app(qq|LibreCat::CLI| => ['project']);
    ok $result->error, 'ok threw an exception';
}

{
    my $result = test_app(qq|LibreCat::CLI| => ['project', 'list']);

    ok !$result->error, 'ok threw no exception';

    my $output = $result->stdout;
    ok $output , 'got an output';

    my $count = count_project($output);

    ok $count == 0, 'got no projects';
}

{
    my $result = test_app(qq|LibreCat::CLI| =>
            ['project', 'add', 't/records/invalid-project.yml']);
    ok $result->error, 'ok threw an exception';
}

{
    my $result = test_app(qq|LibreCat::CLI| =>
            ['project', 'add', 't/records/valid-project.yml']);

    ok !$result->error, 'ok threw no exception';

    my $output = $result->stdout;
    ok $output , 'got an output';

    like $output , qr/^added P9999999/, 'added P9999999';
}

{
    my $result
        = test_app(qq|LibreCat::CLI| => ['project', 'get', 'P9999999']);

    ok !$result->error, 'ok threw no exception';

    my $output = $result->stdout;

    ok $output , 'got an output';

    my $importer = Catmandu->importer('YAML', file => \$output);

    my $record = $importer->first;

    is $record->{_id}, 'P9999999', 'got really a P9999999 record';
}

{
    my $result
        = test_app(qq|LibreCat::CLI| => ['project', 'delete', 'P9999999']);

    ok !$result->error, 'ok threw no exception';

    my $output = $result->stdout;
    ok $output , 'got an output';

    like $output , qr/^deleted P9999999/, 'deleted P9999999';
}

{
    my $result
        = test_app(qq|LibreCat::CLI| => ['project', 'get', 'P9999999']);

    ok $result->error, 'ok no exception';

    my $output = $result->stdout;
    ok length($output) == 0, 'got no result';
}

done_testing;

sub count_project {
    my $str = shift;
    my @lines = grep {!/(^count:|.*\sdeleted\s.*)/} split(/\n/, $str);
    int(@lines);
}
