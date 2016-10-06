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
    $pkg = 'LibreCat::Cmd::research_group';
    use_ok $pkg;
}

require_ok $pkg;

{
    my $result = test_app(qq|LibreCat::CLI| => ['research_group']);
    ok $result->error, 'ok threw an exception';
}

{
    my $result
        = test_app(qq|LibreCat::CLI| =>
            ['research_group', 'add', 't/records/invalid-research_group.yml']
        );
    ok $result->error, 'ok threw an exception';
}

{
    my $result = test_app(qq|LibreCat::CLI| =>
            ['research_group', 'add', 't/records/valid-research_group.yml']);

    ok !$result->error, 'ok threw no exception';

    my $output = $result->stdout;
    ok $output , 'got an output';

    like $output , qr/^added RG999000999/, 'added RG999000999';
}

{
    my $result = test_app(qq|LibreCat::CLI| => ['research_group', 'list']);

    ok !$result->error, 'ok threw no exception';

    my $output = $result->stdout;
    ok $output, 'got an output';

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

    is $record->{_id}, 'RG999000999', 'got really a RG999000999 record';
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
