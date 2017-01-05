use Catmandu::Sane;
use Catmandu;
use LibreCat load => (layer_paths => [qw(t/layer)]);
use LibreCat::CLI;
use Test::More;
use Test::Exception;
use App::Cmd::Tester;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Cmd::publication';
    use_ok $pkg;
}

require_ok $pkg;

# empty db
Catmandu->store('backup')->bag('publication')->delete_all;
Catmandu->store('search')->bag('publication')->drop;

{
    my $result = test_app(qq|LibreCat::CLI| => ['publication']);
    ok $result->error, 'ok threw an exception';
}

{
    my $result = test_app(qq|LibreCat::CLI| => ['publication', 'list']);

    ok !$result->error, 'ok threw no exception';

    my $output = $result->stdout;
    ok $output , 'got an output';

    my $count = count_publication($output);

    ok $count == 0, 'got no publications';
}

{
    my $result = test_app(qq|LibreCat::CLI| =>
            ['publication', 'add', 't/records/invalid-publication.yml']);
    ok $result->error, 'add threw an exception';
}

{
    my $result = test_app(qq|LibreCat::CLI| =>
            ['publication', 'add', 't/records/valid-publication.yml']);

    ok !$result->error, 'add threw no exception';

    my $output = $result->stdout;
    ok $output , 'got an output';

    like $output , qr/^added 999999999/, 'added 999999999';
}

{
    my $result
        = test_app(qq|LibreCat::CLI| => ['publication', 'get', '999999999']);
    ok !$result->error, 'get threw no exception';

    my $output = $result->stdout;

    ok $output , 'got an output';

    my $importer = Catmandu->importer('YAML', file => \$output);

    my $record = $importer->first;

    is $record->{_id}, 999999999, 'got really a 999999999 record';
    is $record->{title}, 'Valid Test Publication', 'got a valid title';
}

{
    my $result = test_app(
        qq|LibreCat::CLI| => ['publication', 'purge', '999999999']);

    ok !$result->error, 'purge threw no exception';

    my $output = $result->stdout;
    ok $output , 'got an output';

    like $output , qr/^purged 999999999/, 'purged 999999999';
}

{
    my $result = test_app(qq|LibreCat::CLI| =>
            ['publication', '--no-citation','add', 't/records/valid-publication-no-citation.yml']);

    ok !$result->error, 'ok threw no exception';

    my $output = $result->stdout;
    ok $output , 'got an output';

    like $output , qr/^added 999999999/, 'added 999999999';

    $result
        = test_app(qq|LibreCat::CLI| => ['publication', 'get', '999999999']);
    $output = $result->stdout;

    like $output, qr/Valid Test Publication/, "got an ouput";
    unlike $output, qr/citation/, "got no citation";
    $result = test_app(
        qq|LibreCat::CLI| => ['publication', 'purge', '999999999']);
}

{
    my $result
        = test_app(qq|LibreCat::CLI| => ['publication', 'get', '999999999']);

    ok $result->error, 'ok no exception';

    my $output = $result->stdout;
    ok length($output) == 0, 'got no result';
}

done_testing;

sub count_publication {
    my $str = shift;
    my @lines = grep {!/(^count:|.*\sdeleted\s.*)/} split(/\n/, $str);
    int(@lines);
}
