use strict;
use warnings;
use Test::More;
use Test::Exception;
use App::Cmd::Tester;
use LibreCat::CLI;

my $pkg;

BEGIN {
    use Catmandu::Sane;
    use Path::Tiny;
    use lib path(__FILE__)->parent->parent->child('lib')->stringify;
    use LibreCat::Layers;

    LibreCat::Layers->new(layer_paths => [qw(t/layer)])->load;

    $pkg = 'LibreCat::Cmd::schemas';
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

{
    my $result = test_app(qq|LibreCat::CLI| => ['audit', 'get', '0']);

    ok $result->error, 'ok threw an exception';
}

done_testing;
