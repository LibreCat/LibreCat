use Catmandu::Sane;
use Test::More;
use Test::Exception;
use IO::File;
use Catmandu;
use Catmandu::DirectoryIndex::Map;
use Catmandu::Store::DBI;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Worker::FileUploader';
    use_ok $pkg;
}

require_ok $pkg;

my $temp_directory = Catmandu::DirectoryIndex::Map->new(
    base_dir => "t/tmp",
    bag      => Catmandu::Store::DBI->new(
                    data_source => "dbi:SQLite:dbname=t/tmp/temp_index.db"
                )->bag()
);

my $file_opts = {
            package => 'Simple',
            options => {
                root => './t/data3'
            }
        };

my $temp_opts = {
            package => 'Simple',
            options => {
                root => './t/tmp' ,
                autocleanup => 1  ,
                directory_index => $temp_directory  ,
            }
        };

my $temp_bag = Catmandu->store('File::Simple', %{$temp_opts->{options}});

# Add some sample data to the temp_store
ok $temp_bag->index->add({ _id => '9000' });

ok $temp_bag->index->files('9000')->upload(
        IO::File->new('<README.md'), 'README.md'
);

dies_ok {
        $pkg->new()
} 'die ok: no args';

lives_ok {
    $pkg->new(
        files      => $file_opts,
        temp_files => $temp_opts,
    )
} 'lives ok: required args';

my $uploader = $pkg->new(
                    files      => $file_opts,
                    temp_files => $temp_opts,
                );
can_ok $uploader, 'work';

my $ret;
lives_ok {
    $ret = $uploader->work(
        {key => 1, filename => 'README.md', tempid => '9000'})
}
"Calling work is safe.";

is $ret , 1, 'work returned the correct response code';

ok -r "t/data3/000/000/001/README.md", "Found the README.md file";

unlink "t/data3/000/000/001/README.md";

done_testing;
