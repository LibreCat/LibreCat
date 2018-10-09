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

    # add some test data
    my $data = [
        { id => 1, process => 'batch', action => 'update', message => 'test1'},
        { id => 2, process => 'web', action => 'update', message => 'test2'},
    ];
    Catmandu->store('main')->bag('audit')->add_many($data);
}

require_ok $pkg;

{
    my $result = test_app(qq|LibreCat::CLI| => ['audit']);
    ok $result->error, 'ok threw an exception: one command needed';

    $result = test_app(qq|LibreCat::CLI| => ['audit', 'do_nonsense']);
    ok $result->error, 'ok threw an exception: invalid nonsense';
}

{
    my $result = test_app(qq|LibreCat::CLI| => ['help', 'audit']);
    ok !$result->error, 'ok threw no exception';

    my $output = $result->stdout;
    like $output, qr/Usage:/, "Help message";
}

{
    my $result = test_app(qq|LibreCat::CLI| => ['audit', 'list']);

    ok !$result->error, 'ok threw no exception';

    my $output = $result->stdout;

    ok $output , 'got an output';

    like $output, qr/count: 2/, 'list count'
}

END {
    # cleanup test data
    Catmandu->store('main')->bag('audit')->delete_all;
}

done_testing;
