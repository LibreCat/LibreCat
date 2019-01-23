use Catmandu::Sane;
use Path::Tiny;
use LibreCat -load => {layer_paths => [qw(t/layer)]};
use LibreCat::CLI;
use Test::More;
use Test::Exception;
use App::Cmd::Tester;
use warnings FATAL => 'all';

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Cmd::repl';
    use_ok $pkg;
}

require_ok $pkg;

subtest 'help' => sub {
    my $result = test_app(qq|LibreCat::CLI| => ['help', 'repl']);
    ok !$result->error, 'ok threw no exception';

    my $output = $result->stdout;
    like $output, qr/Usage:/, "Help message";
};

done_testing;
