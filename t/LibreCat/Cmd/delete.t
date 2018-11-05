use Catmandu::Sane;
use LibreCat -load => {layer_paths => [qw(t/layer)]};
use LibreCat::CLI;
use Test::More;
use Test::Exception;
use App::Cmd::Tester;
use warnings FATAL => 'all';

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Cmd::delete';
    use_ok $pkg;
}

require_ok $pkg;

my $result = test_app(qq|LibreCat::CLI| => ['help', 'delete']);
ok !$result->error, 'ok threw no exception';

my $output = $result->stdout;
like $output, qr/WARNING - Low level command/, "Help message";

done_testing;
