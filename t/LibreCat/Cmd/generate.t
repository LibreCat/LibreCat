use Catmandu::Sane;
use Path::Tiny;
use LibreCat load => (layer_paths => [qw(t/layer)]);

use LibreCat::CLI;
use Test::More;
use Test::Exception;
use App::Cmd::Tester;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Cmd::generate';
    use_ok $pkg;
}

require_ok $pkg;

{
    my $result = test_app(qq|LibreCat::CLI| => ['generate']);

    ok $result->error, 'ok threw an exception';
}

{
    my $result = test_app(qq|LibreCat::CLI| => ['generate', 'package.json']);

    ok !$result->error, 'ok threw no exception';

    ok -f "package.json", "package.json generated";
}

done_testing;

END {
    unlink "package.json";
}
