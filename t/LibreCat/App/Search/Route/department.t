use strict;
use warnings;
use LibreCat load => (layer_paths => [qw(t/layer)]);
use Test::More;
use Dancer::Test;

my $pkg;

BEGIN {
    $pkg = "LibreCat::App::Search::Route::department";
    use_ok $pkg;
}
require_ok $pkg;

route_exists       [GET => '/department'], "GET /department is handled";
response_status_is [GET => '/department'], 200,
    'GET /department status is ok';
response_content_like [GET => '/department'], qr/(?i)department/,
    "content looks good for /department";

done_testing;
