use Catmandu::Sane;
use Dancer;
use Path::Tiny;
use LibreCat load => (layer_paths => [qw(t/layer)]);
use Test::More import => ['!pass'];
use Test::Exception;
use warnings FATAL => 'all';

my $pkg;

BEGIN {
    set plugins =>
        from_yaml(path("t/layer/config.yml")->slurp_utf8)->{plugins};
    $pkg = 'LibreCat::App::Search::Route::api';
    use_ok $pkg;
}

require_ok $pkg;

done_testing;
