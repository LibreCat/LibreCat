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

note("testing valid");
{
    ok test_app(qq|LibreCat::CLI| => ['publication', 'valid'])->error , "no file == error";

    ok test_app(qq|LibreCat::CLI| => ['publication', 'valid','t/blabla'])->error , "not existing file";

    my $result = test_app(qq|LibreCat::CLI| =>
            ['publication', 'valid', 't/records/invalid-publication.yml']);
    ok $result->error, 'invalid publication';

    like $result->stderr , qr/type: Missing property/ , 'missing title';

    my $result2 = test_app(qq|LibreCat::CLI| =>
            ['publication', 'valid', 't/records/valid-publication.yml']);
    ok !$result2->error, 'valid publication';
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
    my $result = test_app(qq|LibreCat::CLI| => [
        'publication',
          'export',
          '--start',0,
          '--total',10
    ]);

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
    my $result = test_app(qq|LibreCat::CLI| => [
        'publication',
          'export',
          '--sort','"title,,1"',
          '--start',1,
          '--total',10,
          'basic = Valid'
    ]);

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

note("testing embargo");
{
    my $result = test_app(qq|LibreCat::CLI| => ['publication', 'embargo']);

    ok ! $result->error , 'got not an error';

    ok ! $result->stdout, 'got an empty result';

    my $record = get_publication('999999999');

    $record->{file} = [{
        access_level => 'local' ,
        content_type => 'application/pdf' ,
        creator      => 'einstein' ,
        date_created => '1970-01-01T00:00:00Z' ,
        date_updated => '1970-01-01T00:00:00Z' ,
        file_id      => 1 ,
        file_name    => 'test.pdf' ,
        file_size    => '1024' ,
        relation     => 'main_file' ,
        embargo_to   => 'open_access' ,
        embargo      => '2000-01-01' ,
    }];

    add_publication($record);

    my $result2 = test_app(qq|LibreCat::CLI| => ['publication', 'embargo']);

    ok ! $result2->error , 'got not an error';

    my $output2 = $result2->stdout;

    ok $output2, 'got an result';

    my $record2 = Catmandu->importer('YAML', file => \$output2)->first;

    ok $record2 , 'got yaml output';

    is $record2->{id} , '999999999' , 'id = 999999999';

    is $record2->{access_level} , 'local' , 'still local access_level';

    my $result3 = test_app(qq|LibreCat::CLI| => ['publication', 'embargo','update']);

    ok ! $result3->error , 'got not an error';

    my $output3 = $result3->stdout;

    my $record3 = Catmandu->importer('YAML', file => \$output3)->first;

    ok $record3 , 'got yaml output';

    is $record3->{id} , '999999999' , 'id = 999999999';

    is $record3->{access_level} , 'open_access' , 'still local open_access';
}

note("testing deleting a publication");
{
    ok test_app(qq|LibreCat::CLI| => ['publication', 'delete'])->error , "no id == error";

    my $result = test_app(
        qq|LibreCat::CLI| => ['publication', 'delete', '666']);

    ok $result->error, 'delete threw an exception';

    my $output = $result->stderr;
    ok $output , 'got an output';

    like $output , qr/delete 666 failed/, 'delete 666 failed';

    my $result2 = test_app(qq|LibreCat::CLI| =>
                ['publication',
                 'delete',
                 '--log','test',
                 '999999999']);

    ok !$result2->error, 'delete threw no exception';

    my $output2 = $result2->stdout;
    ok $output2 , 'got an output';

    like $output2 , qr/deleted 999999999/, 'deleted 999999999';

    my $record = get_publication('999999999');

    ok $record , 'got record 999999999';

    is $record->{status} , 'deleted' , 'status = deleted';
    ok $record->{date_deleted} , 'got a date_deleted';
}

note("testing purging a publication");
{
    ok test_app(qq|LibreCat::CLI| => ['publication', 'purge'])->error , "no id == error";

    my $result = test_app(
        qq|LibreCat::CLI| => ['publication', 'purge', '999999999']);

    ok !$result->error, 'purge threw no exception';

    my $output = $result->stdout;
    ok $output , 'got an output';

    like $output , qr/^purged 999999999/, 'purged 999999999';

    my $record = get_publication('999999999');

    ok ! $record , 'record 999999999 is gone';
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

note("testing fetch");
{
    ok test_app(qq|LibreCat::CLI| => ['publication', 'fetch'])->error , "no source == error";
    ok test_app(qq|LibreCat::CLI| => ['publication', 'fetch','bibtex'])->error , "no id == error";
    ok test_app(qq|LibreCat::CLI| => ['publication', 'fetch','blabla','123'])->error , "no exising source == error";

    my $result = test_app(qq|LibreCat::CLI| => [
                    'publication', 'fetch','bibtex','t/does/not/exists'
                    ]);

    ok !$result->error, "importing a non existing id doesn't give an error";

    my $result2 = test_app(qq|LibreCat::CLI| => [
                    'publication', 'fetch','bibtex','t/records/bibtex-one.txt'
                    ]);

    ok !$result2->error, "valid input";

    my $yaml = $result2->stdout;

    ok $yaml , 'got an output';

    my $importer = Catmandu->importer('YAML', file => \$yaml);

    my $record = $importer->first;

    ok $record , 'got a yaml output';

    is $record->{status} , 'new' , 'got a new record';
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
    Catmandu->store('main')->bag('publication')->commit;
    Catmandu->store('search')->bag('publication')->add($record);
    Catmandu->store('search')->bag('publication')->commit;
}
