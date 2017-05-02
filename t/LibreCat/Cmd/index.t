use Catmandu::Sane;
use Path::Tiny;
use LibreCat load => (layer_paths => [qw(t/layer)]);

use LibreCat::CLI;
use Test::More;
use Test::Exception;
use App::Cmd::Tester;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Cmd::index';
    use_ok $pkg;
}

require_ok $pkg;

{
    my $result = test_app(qq|LibreCat::CLI| => ['index']);
    ok $result->error, 'ok threw an exception';
}

# {
#     my $result = test_app(qq|LibreCat::CLI| => ['index', 'publication']);
#     ok ! $result->error, 'ok threw no exception';
# }

done_testing;
