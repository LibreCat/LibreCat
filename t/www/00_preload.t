use Catmandu::Sane;
use Catmandu;
use Path::Tiny;
use LibreCat load => (layer_paths => [qw(t/layer)]);
use Catmandu;
use LibreCat::CLI;
use Test::More;
use Test::Exception;
use App::Cmd::Tester;

# empty db
for my $bag (qw(publication department project research_group user)) {
    note("deleting backup $bag");
    {
        my $store = Catmandu->store('main')->bag($bag);
        $store->delete_all;
        $store->commit;
    }

    note("deleting version $bag");
    {
        my $store = Catmandu->store('main')->bag("$bag\_version");
        $store->delete_all;
        $store->commit;
    }

    note("deleting search $bag");
    {
        my $store = Catmandu->store('search')->bag($bag);
        $store->delete_all;
        $store->commit;
    }
}

note("cleaning forms");
{
    my $result = test_app(qq|LibreCat::CLI| => ['generate', 'cleanup']);

    print $result->stdout;

    warn $result->stderr if $result->stderr;

    ok !$result->error, 'generate threw no exception';
}

note("generate forms");
{
    my $result = test_app(qq|LibreCat::CLI| => ['generate', 'forms']);

    print $result->stdout;

    warn $result->stderr if $result->stderr;

    ok !$result->error, 'generate threw no exception';
}

note("loading test publications");
{
    my $result
        = test_app(
        qq|LibreCat::CLI| => ['publication', 'add', 'devel/publications.yml']
        );

    ok !$result->error, 'add threw no exception';
}

note("loading test project");
{
    my $result = test_app(
        qq|LibreCat::CLI| => ['project', 'add', 'devel/project.yml']);

    ok !$result->error, 'add threw no exception';
}

note("loading test user");
{
    my $result
        = test_app(qq|LibreCat::CLI| => ['user', 'add', 'devel/user.yml']);
    ok !$result->error, 'add threw no exception';
}

note("loading test department");
{
    my $result = test_app(
        qq|LibreCat::CLI| => ['department', 'add', 'devel/department.yml']);

    ok !$result->error, 'add threw no exception';
}

note("generate departments");
{
    my $result = test_app(qq|LibreCat::CLI| => ['generate', 'departments']);

    print $result->stdout;

    warn $result->stderr if $result->stderr;

    ok !$result->error, 'generate threw no exception';
}

done_testing;
