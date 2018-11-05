use strict;
use warnings FATAL => 'all';
use LibreCat -load => {layer_paths => [qw(t/layer)]};
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
    my $result = test_app(qq|LibreCat::CLI| => ['help', 'url']);
    ok !$result->error, 'ok threw no exception';

    my $output = $result->stdout;
    like $output, qr/Usage:/, "Help message";
}

SKIP: {
    skip("No network. Set NETWORK_TEST to run these tests.", 5)
        unless $ENV{NETWORK_TEST};

    my $result = test_app(qq|LibreCat::CLI| => ['url', 'check']);
    ok $result->error, 'threw an exception';

    $result = test_app(qq|LibreCat::CLI| =>
            ['url', 'check', '--importer=YAML', 't/records/urls.yml']);
    ok !$result->error, 'threw no exception';

    like $result->stdout, qr/2\s+https:\/\/biblio.ugent.be\s+200/,
        'result looks good';

    $result = test_app(
        qq|LibreCat::CLI| => [
            'url',                'check',
            '--importer=YAML',    '--exporter=JSON',
            't/records/urls.yml', 't/tmp/urls.out'
        ]
    );
    ok !$result->error, 'threw no exception with outfile';

    my $importer = Catmandu->importer('JSON', file => 't/tmp/urls.out');

    ok $importer->to_array, 'got JSON results';

    unlink('t/tmp/urls.out');
}

done_testing;
