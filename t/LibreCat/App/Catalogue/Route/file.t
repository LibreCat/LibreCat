use Catmandu::Sane;
use Path::Tiny;
use lib path(__FILE__)->parent->parent->child('lib')->stringify;
use LibreCat -load => {layer_paths => [qw(t/layer)]};
use Test::Exception;
use Test::More import => ['!pass'];
use Test::WWW::Mechanize::PSGI;
use LibreCat::App::Helper;
use IO::File;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::App::Catalogue::Route::file';
    use_ok $pkg;
}

require_ok $pkg;

is LibreCat::App::Catalogue::Route::file::str_format( "%o", i => 1, f => "DS.0", e => "pdf", o => "test.pdf" ), "test.pdf", "str_format %o";
is LibreCat::App::Catalogue::Route::file::str_format( "%i-%f.%e", i => 1, f => "DS.0", e => "pdf", o => "test.pdf" ), "1-DS.0.pdf", "str_format %i-%f.%e";

my $date = LibreCat::App::Catalogue::Route::file::_calc_date();
ok $date, "can calculate date with _calc_date";
like $date, qr/^\d{4}-\d{2}-\d{2}/, "_calc_date returns a date";

my $app = eval {do './bin/app.pl';};
my $mech = Test::WWW::Mechanize::PSGI->new( app => $app );
$mech->max_redirect(0);

note("login");
{
    $mech->get_ok("/login");
    my $res = $mech->submit_form(
        form_number => 1,
        fields      => {user => "einstein", pass => "einstein"},
    );
    is($res->code, 302, "/login redirects, as expected");
}

my $helper = LibreCat::App::Helper::Helpers->new();
my $file_store = $helper->get_file_store();
my $pubs = LibreCat->instance->model("publication");

my $record_id = $pubs->generate_id;
my $file_id = "AC";
my $file_name = "publication.pdf";
my $source_file = "t/data3/000/000/001/$file_name";
my $file_size = -s $source_file;

$pubs->delete_all;
$file_store->index->delete_all;

my $r;
note("upload some files");
{

    $file_store->index->add({ _id => $record_id });
    my $files = $file_store->index->files( $record_id );
    my $ok = $files->upload( IO::File->new($source_file), $file_name );

    $files->upload(
        IO::File->new( "t/data3/000/000/001/utf8.txt" ),
        "utf8.txt"
    );

    $r = {
        _id => $record_id,
        title => $file_name,
        status => "public",
        type => "book",
        user_id => 1234,
        creator => {
            id => 1234,
            login => "einstein"
        },
        author => [{
            id => 1234,
            first_name => "Albert",
            last_name => "Einstein",
            full_name => "Albert Einstein"
        }],
        file => [
            {
                file_id => $file_id,
                file_name => $file_name,
                file_size => int( $file_size ),
                content_type => "application/pdf",
                creator => 1234,
                access_level => "open_access",
                open_access => 1,
                relation => "main_file",
                date_created => "2018-08-06T11:46:00Z",
                date_updated => "2018-08-06T11:46:00Z",
                title => $file_name
            },
            {
                file_id => "TXT",
                file_name => "utf8.txt",
                file_size => -s "t/data3/000/000/001/utf8.txt",
                content_type => "text/plain",
                creator => 1234,
                access_level => "closed",
                open_access => 1,
                relation => "main_file",
                date_created => "2018-08-06T11:46:00Z",
                date_updated => "2018-08-06T11:46:00Z"
            }
        ]
    };
    $pubs->bag->add($r);
    $pubs->search_bag->add($r);
    $pubs->bag->commit();
    $pubs->search_bag->commit;
}

note("download open access file");
{
    $mech->max_redirect(0);
    $mech->get_ok("/download/$record_id/$file_id/$file_name");
    is( $mech->content_type, "application/pdf", "content type set correctly" );
}


note("download closed access file");
{
    $mech->max_redirect(0);
    $mech->get_ok("/download/$record_id/TXT/utf8.txt");
    # is( $mech->content_type, "application/pdf", "content type set correctly" );
}

note("logout now");
{
    ok $mech->get("/logout"), "logged out";
    is($mech->status, 302, "redirected after logout");
}

note("try downloads after logout");
{
    $mech->max_redirect(0);
    ok $mech->get("/download/$record_id/TXT/utf8.txt"), "can get download";
    is($mech->status, 403, "forbidden: status 403");

    $mech->get_ok("/download/$record_id/$file_id/$file_name");
}

note("try to download missing file");
{
    $mech->max_redirect(0);
    ok $mech->get("/download/$record_id/63245/missing.pdf"), "request to missing file";
    is($mech->status, 404, "not found: status 404");
}

# TODO: download oa file, but record not private
note("hide record from public and try to download");
{
    $r->{status} = "returned";
    $pubs->bag->add($r);
    $pubs->search_bag->add($r);
    $pubs->bag->commit();
    $pubs->search_bag->commit;
    $mech->max_redirect(0);
    $mech->get("/download/$record_id/$file_id/$file_name");
    is ($mech->status, 403, "forbidden: status 403");
}

# #headers for all content types except 'text/plain'
# {
#     $mech->max_redirect(0);
#     $mech->get_ok("/download/$record_id/$file_id/$file_name");
#     is( $mech->response()->header("Content-Disposition"), "attachment; filename*=UTF-8''publication.pdf", "content disposition set to attachment for all content types" );
#     $mech->max_redirect(0);
# }
#
# #headers for content type 'text/plain'
# {
#     $mech->max_redirect(0);
#     $mech->get_ok("/download/$record_id/TXT/utf8.txt");
#     is( $mech->response()->header("Content-Disposition"), "inline; filename*=UTF-8''utf8.txt", "content disposition set to inline for specific content type" );
#     is( $mech->response()->header("Content-Type"), "text/plain; charset=utf-8", "content-type reset for specific content type" );
#     $mech->max_redirect(0);
# }

$pubs->delete_all;
$file_store->index->delete_all;

done_testing;
