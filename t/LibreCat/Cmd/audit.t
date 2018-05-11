use strict;
use warnings;
use Test::More;
use Test::Exception;
use App::Cmd::Tester;
use LibreCat -load => {layer_paths => [qw(t/layer)]};
use LibreCat::CLI;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Cmd::audit';
    use_ok $pkg;
}

require_ok $pkg;

{
    my $result = test_app(qq|LibreCat::CLI| => ['audit']);
    ok $result->error, 'ok threw an exception: one command needed';

    $result = test_app(qq|LibreCat::CLI| => ['audit', 'do_nonsense']);
    ok $result->error, 'ok threw an exception: invalid nonsense';
}

{
    my $result = test_app(qq|LibreCat::CLI| => ['audit', 'list']);

    ok !$result->error, 'ok threw no exception';

    my $output = $result->stdout;

    ok $output , 'got an output';
}

done_testing;
