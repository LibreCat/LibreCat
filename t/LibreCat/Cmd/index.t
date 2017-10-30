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
    ok $result->error, 'ok index threw an exception';
}

{
    my $result = test_app(qq|LibreCat::CLI| => ['index', '--yes' , 'initialize']);
    ok ! $result->error, 'ok initialize threw no exception';
}

{
    my $result = test_app(qq|LibreCat::CLI| => ['index','status']);
    ok ! $result->error, 'ok status threw no exception';
}

{
    my $result = test_app(qq|LibreCat::CLI| => ['index','create', 'publication']);
    ok ! $result->error, 'ok create threw no exception';
}

{
    my $result = test_app(qq|LibreCat::CLI| => ['index','drop','publication']);
    ok ! $result->error, 'ok drop threw no exception';
}

{
    my $result = test_app(qq|LibreCat::CLI| => ['index','purge']);
    ok ! $result->error, 'ok purge threw no exception';
}

# Re-initialize and switch
{
    my $result = test_app(qq|LibreCat::CLI| => ['index','--yes','initialize']);
    ok ! $result->error, 'ok initialize threw no exception';
}

{
    my $result = test_app(qq|LibreCat::CLI| => ['index','switch']);
    ok ! $result->error, 'ok switch threw no exception';
}

done_testing;
