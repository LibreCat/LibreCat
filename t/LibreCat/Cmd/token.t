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

{
    my $result = test_app(qq|LibreCat::CLI| => ['token','encode','rubbish']);
    ok(
        index( $result->stderr, "unable to parse json" ) >= 0,
        "supply valid json object"
    );
}

{
    my $result = test_app(qq|LibreCat::CLI| => ['token','encode','[]']);
    ok(
        index( $result->stderr, "supplied payload should be a hash" ) >= 0,
        "supplied payload should be a hash"
    );
}
{
    my $result = test_app(qq|LibreCat::CLI| => ['token','encode','{}']);
    is( $result->exit_code, 0, "empty payload is ok" );
    ok( length( $result->stdout ) > 1, "empty payload returns a valid token" );
}
{
    my $result = test_app(qq|LibreCat::CLI| => ['token','encode','{ "model":"publication" }']);
    is( $result->exit_code, 0, "payload.model=publication is ok" );
}
{
    my $result = test_app(qq|LibreCat::CLI| => ['token','encode','{ "model":"rubbish" }']);
    ok(
        index( $result->stderr, "jwt payload not accepted" ) >= 0 &&
        index( $result->stderr, "allowed values for model" ) >= 0,
        "payload.model=rubbish is not ok"
    );
}

done_testing;
