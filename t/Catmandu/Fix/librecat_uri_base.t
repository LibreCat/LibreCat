use Catmandu::Sane;
use LibreCat load => (layer_paths => [qw(t/layer)]);
use Test::More;

my $pkg;

BEGIN {
    $pkg = 'Catmandu::Fix::librecat_uri_base';
    use_ok $pkg;
}
require_ok $pkg;

is_deeply $pkg->new('uri_base')->fix({}),
    {uri_base => 'http://localhost:5001',}, "add uri_base to empty hash";

is_deeply $pkg->new('uri_base')->fix({data => 1}),
    {data => 1, uri_base => 'http://localhost:5001',},
    "add uri_base to non-empty hash";

done_testing;
