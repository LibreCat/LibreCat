use Catmandu::Sane;
use Path::Tiny;
use LibreCat load => (layer_paths => [qw(t/layer)]);

use LibreCat::CLI;
use Test::More;
use Test::Exception;
use App::Cmd::Tester;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Cmd::repl';
    use_ok $pkg;
}

require_ok $pkg;

done_testing;
