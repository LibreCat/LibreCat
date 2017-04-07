use Catmandu::Sane;
use LibreCat load => (layer_paths => [qw(t/layer)]);
use Test::More;
use Dancer::Test;

my $pkg;

BEGIN {
    $pkg = "LibreCat::App::Search::Route::export";
    use_ok $pkg;
}
require_ok $pkg;

my $store = Catmandu->store('search');
my $bag   = $store->bag('publication');
$bag->delete_all;
my $importer
    = Catmandu->importer('YAML', file => 't/records/valid-publication.yml');
$bag->add_many($importer);
$bag->commit;

{
    route_exists       [GET => '/export'], "GET /export is handled";
    response_status_is [GET => '/export'], 406,
        "GET /export status without format is ok";
}

{
    route_exists [GET => '/export?fmt=json'],
        "GET /export?fmt=json is handled";

    response_status_is [GET => '/export?fmt=json'], 200,
        "GET /export?fmt=json is ok";

    response_content_like [GET => '/export?fmt=json'],
        qr/"title":"Valid Test Publication"/,
        "GET /export?fmt=json looks like JSON";

    response_content_like [GET => '/export?fmt=yaml'],
        qr/title: Valid Test Publication/, "GET /export?fmt=yaml like YAML";

    response_content_like [GET => '/export?fmt=ris'],
        qr/TI\s+-\s+Valid Test Publication/, "GET /export?fmt=ris like RIS";

    response_content_like [GET => '/export?fmt=bibtex'],
        qr/title\s+=\s+\{+Valid Test Publication\}+/,
        "GET /export?fmt=bibtex like BIBTEX";

    response_content_like [GET => '/export?fmt=rtf'], qr/\{\\rtf1\\ansi/,
        "GET /export?fmt=rtf like RTF";

    response_content_like [GET => '/export?fmt=aref'],
        qr/dct_title: Valid Test Publication\@/,
        "GET /export?fmt=aref like AREF";

    response_content_like [GET => '/export?fmt=mods'],
        qr/<title>Valid Test Publication<\/title>/,
        "GET /export?fmt=mods like MODS";

    response_content_like [GET => '/export?fmt=dc'],
        qr/<dc:title>Valid Test Publication<\/dc:title>/,
        "GET /export?fmt=dc like DC";

    response_content_like [GET => '/export?fmt=dc_json'],
        qr/"title":\["Valid Test Publication"\]/,
        "GET /export?fmt=dc_json like DC_JSON";

    response_content_like [GET => '/export?fmt=csl_json'],
        qr/"title" : "Valid Test Publication"/,
        "GET /export?fmt=csl_json like CSL_JSON";

    response_status_is [GET => '/export?fmt=bla'], 406,
        "GET /export status for invalid format is ok";

    response_content_like [GET => '/export?fmt=bla'], qr/error/,
        "GET /export?fmt=bla&bag=publication error message ok";

    response_content_like [GET => '/export?fmt=json&cql=id%3D999999999'],
        qr/"title":"Valid Test Publication"/,
        "GET /export?fmt=json&cql=id%3D999999999json looks like JSON";

    response_content_like [GET => '/export?fmt=json&cql=id%3DBLABLABLA'],
        qr/^\[\]$/, "GET /export?fmt=json&cql=id%3DBLABLABLA looks like JSON";
}

{
    route_exists [GET => '/publication/999999999.json'],
        "GET /publication/:ID is handled";
    response_status_is [GET => '/publication/999999999.json'], 200,
        "GET /publication/:ID status is ok";
}

done_testing;
