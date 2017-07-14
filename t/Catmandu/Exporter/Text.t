use Catmandu::Sane;
use Catmandu;
use Path::Tiny;
use LibreCat load => (layer_paths => [qw(t/layer)]);
use Test::More;
use Test::Exception;

my $pkg;

BEGIN {
    $pkg = "Catmandu::Exporter::Text";
    use_ok $pkg;
}
require_ok $pkg;

done_testing;
