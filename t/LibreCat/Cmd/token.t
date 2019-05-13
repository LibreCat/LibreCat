use Catmandu::Sane;
use LibreCat -load => {layer_paths => [qw(t/layer)]};
use App::Cmd::Tester;
use LibreCat::CLI;
use Test::More;
use Test::Exception;
use warnings FATAL => 'all';

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Cmd::token';
    use_ok $pkg;
};

require_ok $pkg;
{
    my $result = test_app(qq|LibreCat::CLI| => ['token']);
    ok $result->error, 'missing command';
}

{
    my $result = test_app(qq|LibreCat::CLI| => ['help', 'token']);
    ok !$result->error, 'help message for token cmd';

    my $output = $result->stdout;
    like $output, qr/Usage:/, "Help message";
}

{
    my $result = test_app(qq|LibreCat::CLI| => ['token', 'encode']);
    ok !$result->error, 'no error for token cmd';

    ok $result->output, 'got an output for token cmd';
    ok length $result->output > 40, 'output looks good';
}

done_testing;
