use strict;
use warnings FATAL => 'all';

use Path::Tiny;
use LibreCat -load => {layer_paths => [qw(t/layer)]};
use Test::More;
use Test::Exception;
use App::Cmd::Tester;
use File::Temp qw(tempfile);
use LibreCat::CLI;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Cmd::worker';
    use_ok $pkg;
}

require_ok $pkg;

{
    my $result = test_app(qq|LibreCat::CLI| => ['worker']);

    ok $result->error, 'ok threw an exception';
    like $result->error, qr/should be one of/, 'got expected output';
}

{
    my $result = test_app(qq|LibreCat::CLI| => ['help', 'worker']);
    ok !$result->error, 'ok threw no exception';

    my $output = $result->stdout;
    like $output, qr/Usage:/, "Help message";
}

done_testing;
