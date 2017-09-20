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
    my $result = test_app(qq|LibreCat::CLI| => ['schemas']);
    ok $result->error, 'ok threw an exception';
}

{
    my $result = test_app(qq|LibreCat::CLI| => ['schemas', 'list']);

    ok !$result->error, 'ok threw no exception';

    my $output = $result->stdout;
    ok $output , 'got an output';

    like $output, qr/$_/, "$_ is listed"
        for qw(publication research_group project user department)
}

{
    my $result = test_app(qq|LibreCat::CLI| => ['schemas', 'get']);
    ok $result->error, 'ok threw an exception';

}

{
    my $result
        = test_app(qq|LibreCat::CLI| => ['schemas', 'get', 'publication']);
    ok !$result->error, 'ok threw no exception';
    like $result->stdout, qr/title/, 'content looks good';
}

{
    my $result = test_app(qq|LibreCat::CLI| => ['schemas', 'markdown']);
    ok !$result->error, 'ok threw no exception';
    like $result->stdout, qr/# publication/, 'content looks good';
}

done_testing;
