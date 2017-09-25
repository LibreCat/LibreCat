use strict;
use warnings FATAL => 'all';
use LibreCat load => (layer_paths => [qw(t/layer)]);
use LibreCat::CLI;
use Test::More;
use Test::Exception;
use App::Cmd::Tester;
use Data::Dumper;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Cmd::url';
    use_ok $pkg;
}

require_ok $pkg;

{
    my $result = test_app(qq|LibreCat::CLI| => ['url']);
    ok $result->error, 'threw an exception: cmd missing';

    $result = test_app(qq|LibreCat::CLI| => ['url', 'do_nonsense']);
    ok $result->error, 'threw an exception: cmd unknown';
}

{
    my $result = test_app(qq|LibreCat::CLI| => ['url', 'check']);
    ok $result->error, 'threw an exception';

    $result = test_app(
        qq|LibreCat::CLI| => ['url', 'check', 't/records/urls.yml']);
    ok !$result->error, 'threw no exception';

    like $result->stdout, qr/200.*pub\.uni-bielefeld/, 'result looks good';
    like $result->stdout, qr/200.*biblio\.ugent/,      'result looks good';

    $result = test_app(qq|LibreCat::CLI| =>
            ['url', 'check', 't/records/urls.yml', 't/tmp/urls.out']);
    ok !$result->error, 'threw no exception with outfile';

    unlink('t/tmp/urls.out');
}

done_testing;
