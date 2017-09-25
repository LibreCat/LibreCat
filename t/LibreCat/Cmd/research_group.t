use Catmandu::Sane;
use Path::Tiny;
use LibreCat load => (layer_paths => [qw(t/layer)]);

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

{
    my $result = test_app(qq|LibreCat::CLI| => ['research_group']);
    ok $result->error, 'ok threw an exception';
}

{
    my $result = test_app(qq|LibreCat::CLI| => ['research_group', 'list']);

    ok !$result->error, 'ok threw no exception';

    my $output = $result->stdout;
    ok $output , 'got an output';

    my $count = count_research_group($output);

    ok $count == 0, 'got no research groups';
}

{
    my $result
        = test_app(qq|LibreCat::CLI| =>
            ['research_group', 'add', 't/records/invalid-research_group.yml']
        );
    ok $result->error, 'add invalid RG: threw an exception';
}

{
    my $result = test_app(qq|LibreCat::CLI| =>
            ['research_group', 'add', 't/records/valid-research_group.yml']);

    ok !$result->error, 'add valid RG: threw no exception';

    my $output = $result->stdout;
    ok $output , 'add: got an output';

    like $output , qr/^added RG999000999/, 'added RG999000999';
}

{
    my $result = test_app(qq|LibreCat::CLI| => ['research_group', 'list']);

    ok !$result->error, 'list';

    my $output = $result->stdout;
    ok $output, 'list: got an output';

    my $count = count_research_group($output);

    ok $count > 0, 'got more than one research_group';
}

{
    my $result = test_app(
        qq|LibreCat::CLI| => ['research_group', 'get', 'RG999000999']);

    ok !$result->error, 'ok threw no exception';

    my $output = $result->stdout;

    ok $output , 'got an output';

    my $importer = Catmandu->importer('YAML', file => \$output);

    my $record = $importer->first;

    is $record->{_id},  'RG999000999', 'got really a RG999000999 record';
    is $record->{name}, 'TestGroup',   'got a valid name';
}

{
    my $result = test_app(
        qq|LibreCat::CLI| => ['research_group', 'delete', 'RG999000999']);

    ok !$result->error, 'ok threw no exception';

    my $output = $result->stdout;
    ok $output , 'got an output';

    like $output , qr/^deleted RG999000999/, 'deleted RG999000999';
}

{
    my $result = test_app(
        qq|LibreCat::CLI| => ['research_group', 'get', 'RG999000999']);

    ok $result->error, 'ok no exception';

    my $output = $result->stdout;
    ok length($output) == 0, 'got no result';
}

done_testing;

sub count_research_group {
    my $str = shift;
    my @lines = grep {!/(^count:|.*\sdeleted\s.*)/} split(/\n/, $str);
    int(@lines);
}
