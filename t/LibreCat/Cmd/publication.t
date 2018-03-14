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
Catmandu->store('main')->bag('publication')->delete_all;
Catmandu->store('search')->bag('publication')->delete_all;

note("testing basic options");
{
    my $result = test_app(qq|LibreCat::CLI| => ['publication']);
    ok $result->error, 'ok threw an exception';

    my $result2 = test_app(qq|LibreCat::CLI| => ['help', 'publication']);

    my $output2 = $result2->stdout;
    ok $output2 , 'got an output';

    like $output2 , qr/Usage:/ , 'got help documentation';

    my $result3 = test_app(qq|LibreCat::CLI| => ['publication','aaaargh']);
    ok $result3->error, 'ok threw an exception';
}

note("testing publication lists");
{
    my $result = test_app(qq|LibreCat::CLI| => ['publication', 'list']);

    ok !$result->error, 'ok threw no exception';

    my $output = $result->stdout;
    ok $output , 'got an output';

    my $count = count_publication($output);

    ok $count == 0, 'got no publications';
}

note("testing adding invalid publications");
{
    my $result = test_app(qq|LibreCat::CLI| =>
            ['publication', 'add', 't/records/invalid-publication.yml']);
    ok $result->error, 'add invalid publication: threw an exception';
}

note("testing adding valid publications");
{
    my $result = test_app(qq|LibreCat::CLI| =>
            ['publication', 'add', 't/records/valid-publication.yml']);

    ok !$result->error, 'add valid publication: threw no exception';

    my $output = $result->stdout;
    ok $output , 'got an output';

    like $output , qr/^added 999999999/, 'added 999999999';
}

note("testing exporting publications");
{
    my $result = test_app(qq|LibreCat::CLI| => ['publication', 'export']);

    ok !$result->error, 'ok threw no exception';

    my $output = $result->output;

    my $importer = Catmandu->importer('YAML', file => \$output);

    ok $importer , 'got a YAML output';

    my $records = $importer->to_array;

    ok $records , 'got records';

    is @$records , 1 , 'got 1 record';
}

note("testing searching publications");
{
    my $result = test_app(qq|LibreCat::CLI| => ['publication', 'export', 'basic = Valid']);

    ok !$result->error, 'ok threw no exception';

    my $output = $result->output;

    my $importer = Catmandu->importer('YAML', file => \$output);

    ok $importer , 'got a YAML output';

    my $records = $importer->to_array;

    ok $records , 'got records';

    is @$records , 1 , 'got 1 record';
}

note("testing getting publication metadata");
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

note("adding a file to the file store");
{
    my $result = test_app(
        qq|LibreCat::CLI| => ['file_store', 'add', '999999999', 'cpanfile']);

    ok !$result->error, 'add file threw no exception';

    my $output = $result->stdout;
    ok $output , 'got an output';

    like $output , qr/^key: 999999999/, 'added cpanfile to 999999999';

    ok -r 't/data/999/999/999/cpanfile', 'got a file';
}

note("testing file metadata updates (adding files)");
{
    my $result = test_app(qq|LibreCat::CLI| =>
            ['publication', 'files', 't/records/update_file.yml']);

    ok !$result->error, 'files threw no exception';

    ok $result->stdout, 'got an output';

    my $record = get_publication('999999999');

    ok $record , 'got a record';

    ok $record->{file}, 'record has files';

    is $record->{file}->[0]->{file_id}, '2037', 'got a file_id';

    is $record->{file}->[0]->{access_level}, 'open_access',
        'got a access_level';

    is $record->{file}->[0]->{file_name}, 'cpanfile', 'got a file_name';
}

note("testing file metadata updates (updates)");
{
    my $record = get_publication('999999999');

    $record->{file}->[0]->{access_level} = 'local';

    add_publication($record);

    my $result = test_app(qq|LibreCat::CLI| =>
            ['publication', 'files', 't/records/update_file.yml']);

    ok !$result->error, 'files threw no exception';

    ok $result->stdout, 'got an output';

    $record = get_publication('999999999');

    ok $record , 'got a record';

    is $record->{file}->[0]->{access_level}, 'open_access',
        'got a access_level';
}

note("testing file metadata updates (deletes)");
{
    my $record = get_publication('999999999');

    my $file_new = {%{$record->{file}->[0]}};
    $file_new->{file_id} += 1;

    push @{$record->{file}}, $file_new;

    add_publication($record);

    my $result = test_app(qq|LibreCat::CLI| =>
            ['publication', 'files', 't/records/update_file.yml']);

    ok $result->error, 'ok we get an exception';

    like $result->error, qr/cowardly refusing to delete/;
}

note("deleting the container from the file store");
{
    my $result
        = test_app(qq|LibreCat::CLI| => ['file_store', 'purge', '999999999']);

    ok !$result->error, 'purge threw no exception';

    my $output = $result->stdout;

    is $output , "", 'got no output';

    ok !-d 't/data/999/999/999', 'container is gone';
}

note("testing deleting a publication");
{
    my $result = test_app(
        qq|LibreCat::CLI| => ['publication', 'purge', '999999999']);

    ok !$result->error, 'purge threw no exception';

    my $output = $result->stdout;
    ok $output , 'got an output';

    like $output , qr/^purged 999999999/, 'purged 999999999';
}

note("testing adding publication with --no-citation");
{
    my $result = test_app(
        qq|LibreCat::CLI| => [
            'publication', '--no-citation',
            'add',         't/records/valid-publication-no-citation.yml'
        ]
    );

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

    ok !$result->error, 'publication purged';
}

done_testing;

sub count_publication {
    my $str = shift;
    my @lines = grep {!/(^count:|.*\sdeleted\s.*)/} split(/\n/, $str);
    int(@lines);
}

sub get_publication {
    my $id = shift;
    Catmandu->store('main')->bag('publication')->get($id);
}

sub add_publication {
    my $record = shift;
    Catmandu->store('main')->bag('publication')->add($record);
}
