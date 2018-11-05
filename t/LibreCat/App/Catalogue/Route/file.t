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

#login
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

#upload file
{

    $file_store->index->add({ _id => $record_id });
    my $files = $file_store->index->files( $record_id );
    my $ok = $files->upload( IO::File->new($source_file), $file_name );

    my $r = {
        _id => $record_id,
        title => $file_name,
        status => "published",
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
            }
        ]
    };
    $pubs->bag->add($r);
    $pubs->search_bag->add($r);
    $pubs->bag->commit();
    $pubs->search_bag->commit;
}

#get file
{
    $mech->max_redirect(1);
    $mech->get_ok("/download/$record_id/$file_id/$file_name");
    is( $mech->content_type, "application/pdf", "content type set correctly" );
    $mech->max_redirect(0);
}

$pubs->delete_all;
$file_store->index->delete_all;

done_testing;
