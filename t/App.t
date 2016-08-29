BEGIN {
    use Catmandu::Sane;
    use Path::Tiny;
    use LibreCat::Layers;
    LibreCat::Layers->new->load;
};

use strict;
use warnings;
use lib qw(./lib);
use Test::More tests => 21;

use Dancer ':syntax';
use Dancer::Test;
use App;
use App::Helper;

h->config->{default_lang} = 'en';

route_exists          [GET => '/'], "GET /publications is handled";
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
