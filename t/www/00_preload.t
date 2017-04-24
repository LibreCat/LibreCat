use Catmandu::Sane;
use Catmandu;
use LibreCat load => (layer_paths => [qw(t/layer)]);
use LibreCat::CLI;
use Test::More;
use Test::Exception;
use App::Cmd::Tester;


# empty db
{
    my $store = Catmandu->store('backup')->bag('publication');
    $store->delete_all;
    $store->commit;
}
{
    my $store = Catmandu->store('search')->bag('publication');
    $store->drop;
    $store->commit;
}

note("loading test publications");
{
    my $result = test_app(qq|LibreCat::CLI| =>
        ['publication', 'add', 'devel/publications.yml']);

    ok !$result->error, 'add threw no exception';
}

note("loading test project");
{
    my $result = test_app(qq|LibreCat::CLI| =>
        ['project', 'add', 'devel/project.yml']);

    ok !$result->error, 'add threw no exception';
}

note("loading test researcher");
{
    my $result = test_app(qq|LibreCat::CLI| =>
        ['user', 'add', 'devel/researcher.yml']);

    ok !$result->error, 'add threw no exception';
}

note("loading test department");
{
    my $result = test_app(qq|LibreCat::CLI| =>
        ['department', 'add', 'devel/department.yml']);

    ok !$result->error, 'add threw no exception';
}

done_testing;
