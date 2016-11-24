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
my $bag = $store->bag('publication');
$bag->delete_all;
my $importer = Catmandu->importer('YAML', file => 't/records/valid-publication.yml');
$bag->add_many($importer);
$bag->commit;

{
    route_exists [GET => '/export'],
        "GET /export is handled";
    response_status_is [GET => '/export'], 406,
        "GET /export status without format is ok";
}

{
    route_exists [GET => '/export?fmt=json&bag=publication'],
        "GET /export/publication is handled";
    response_status_is [GET => '/export?fmt=json&bag=publication'], 200,
        "GET /export/publication status is ok";

    response_status_is [GET => '/export?fmt=bla&bag=publication'], 406,
        "GET /export/publication status is ok";
    response_content_like [GET => '/export?fmt=bla&bag=publication'], qr/error/,
        "GET /export?fmt=bla&bag=publication error message ok";

}

{
    route_exists [GET => '/export/publication/999999999?fmt=json'],
        "GET /export/publication/:ID is handled";
    response_status_is [GET => '/export/publication/999999999?fmt=json'], 200,
        "GET /export/publication/:ID status is ok";
}

done_testing;
