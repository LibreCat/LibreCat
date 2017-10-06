use strict;
use warnings FATAL => "all";
use Catmandu::Util qw/require_package/;
use Test::More;
use LibreCat load => (layer_paths => [qw(t/layer)]);

my $pkg;

BEGIN {
    $pkg = 'Catmandu::Fix::file_upload';
    use_ok $pkg;
}
require_ok $pkg;

my $file_json1 = '{"date_updated":"2017-10-06T06:26:28Z","file_size":1000,"success":1,"date_created":"2017-10-06T06:26:28Z","access_level":"open_access","file_id":"999","creator":"einstein","open_access":1,"file_name":"testfile1.pdf","relation":"main_file","content_type":"application/pdf"}';
my $file_json2 = '{"file_size":"2000","open_access":1,"relation":"main_file","access_level":"open_access","file_id":"9991","success":1,"file_name":"testfile2.pdf","date_created":"2017-10-06T06:45:17Z","creator":"einstein","content_type":"application/pdf","date_updated":"2017-10-06T06:45:17Z"}';

is_deeply $pkg->new()->fix(
    {
        _id => 1,
        title => "Test File upload",
        author => "This test does not care about authors",
        file => [$file_json1, $file_json2],
    }
    ),
    {
        _id => 1,
        title => "Test File upload",
        author => "This test does not care about authors",
        file => [
            {
                "access_level" => "open_access",
                "content_type" => "application/pdf",
                "creator" => "einstein",
                "date_created" => "2017-10-06T06:26:28Z",
                "date_updated" => "2017-10-06T06:26:28Z",
                "file_id" => "999",
                "file_name" => "testfile1.pdf",
                "file_size" => "1000",
                "open_access" => "1",
                "relation" => "main_file",
                "success" => "1",
            },
            {
                "access_level" => "open_access",
                "content_type" => "application/pdf",
                "creator" => "einstein",
                "date_created" => "2017-10-06T06:45:17Z",
                "date_updated" => "2017-10-06T06:45:17Z",
                "file_id" => "9991",
                "file_name" => "testfile2.pdf",
                "file_size" => "2000",
                "open_access" => "1",
                "relation" => "main_file",
                "success" => "1",
            },
        ]
    },
    "convert file structure";

done_testing;
