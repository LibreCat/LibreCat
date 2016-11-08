use Catmandu::Sane;
use Path::Tiny;
use lib path(__FILE__)->parent->parent->parent->child('lib')->stringify;
use LibreCat load => (layer_paths => [qw(t/layer)]);
use Test::More;
use Dancer::Test;
use App::Cmd::Tester;
use LibreCat::CLI;

my $pkg;
BEGIN {
    $pkg = "LibreCat::App";
    use_ok $pkg;
}
require_ok $pkg;

Catmandu->config->{default_lang} = 'en';
Catmandu->store('backup')->bag('publication')->delete_all;
Catmandu->store('search')->bag('publication')->drop;

foreach my $obj (qw(publication project researcher)) {
    my $result = test_app(qq|LibreCat::CLI| =>
            [$obj, "add", "t/records/valid-$obj.yml"]);
}

route_exists          [GET => '/'], "GET / is handled";
response_status_is    [GET => '/'], 200, 'GET / status is ok';
response_content_like [GET => '/'], qr/Search Publications/,
    "content looks good for /";

route_exists       [GET => '/publication'], "GET /publications is handled";
response_status_is [GET => '/publication'], 200,
    'GET /publication status is ok';
response_content_like [GET => '/publication'], qr/Publications/,
    "content looks good for /publication";

route_exists          [GET => '/person'], "GET /person is handled";
response_status_is    [GET => '/person'], 200, 'GET /person status is ok';
response_content_like [GET => '/person'], qr/Authors/,
    "content looks good for /person";

route_exists          [GET => '/data'], "GET /data is handled";
response_status_is    [GET => '/data'], 200, 'GET /data status is ok';
response_content_like [GET => '/data'], qr/Data Publications/,
    "content looks good for /data";

route_exists          [GET => '/project'], "GET /data is handled";
response_status_is    [GET => '/project'], 200, 'GET /data status is ok';
response_content_like [GET => '/project'], qr/Project/,
    "content looks good for /project";

route_exists          [GET => '/oai'], "GET /oai is handled";
response_status_is    [GET => '/oai'], 200, 'GET /oai status is ok';
response_content_like [GET => '/oai'], qr/OAI-PMH/,
    "content looks good for /oai";

route_exists          [GET => '/sru'], "GET /sru is handled";
response_status_is    [GET => '/sru'], 200, 'GET /sru status is ok';
response_content_like [GET => '/sru'], qr/explainResponse/,
    "content looks good for /sru";

route_exists          [GET => '/login'], "GET /login is handled";
response_status_is    [GET => '/login'], 200, 'GET /login status is ok';
response_content_like [GET => '/login'], qr/Login/,
    "content looks good for /login";

done_testing;
