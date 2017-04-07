use strict;
use warnings;
use LibreCat load => (layer_paths => [qw(t/layer)]);
use Test::More;
use Dancer::Test;

my $pkg;
BEGIN {
    $pkg = "LibreCat::App::Search::Route::project";
    use_ok $pkg;
}
require_ok $pkg;

subtest '/project' => sub {
    route_exists [GET => '/project'], "GET is handled";
    response_status_is [GET => '/project'], 200, 'GET status is ok';
    response_content_like [GET => '/project'], qr/(?i)project/,
        "content looks good";
};

subtest '/project/A' => sub {
    route_exists [GET => '/project/A'], "GET is handled";
    response_status_is [GET => '/project/A'], 200, 'GET status is ok';
    response_content_like [GET => '/project/A'], qr/(?i)project/,
        "content looks good";
};

subtest '/project/e' => sub {
    route_exists [GET => '/project/e'], "GET is handled";
    response_status_is [GET => '/project/e'], 200, 'GET status is ok';
    response_content_like [GET => '/project/e'], qr/(?i)project/,
        "content looks good";
};

done_testing;
