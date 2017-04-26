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
    my $result = test_app(qq|LibreCat::CLI| => ['generate', 'forms']);

    print $result->stdout;

    print $result->stderr if $result->stderr;

    ok !$result->error, 'ok threw no exception';
}

{
    my $result = test_app(qq|LibreCat::CLI| => ['generate', 'package.json']);

    print $result->stdout;

    print $result->stderr if $result->stderr;

    ok !$result->error, 'ok threw no exception';

    ok -f "package.json", "package.json generated";
}

{
    my $result = test_app(qq|LibreCat::CLI| => ['generate', 'departments']);

use Data::Dumper;
print Dumper($result);

    print $result->stdout;

    print $result->stderr;

    ok !$result->error, 'ok threw no exception';

    ok -f "t/layer/views/department/nodes.tt", "departments nodes generated";

    ok -f "t/layer/views/department/nodes_backend.tt", "departments backend generated";
}

done_testing;

END {
    unlink "package.json";
}
