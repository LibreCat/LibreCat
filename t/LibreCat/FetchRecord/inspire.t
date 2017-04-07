use strict;
use warnings FATAL => 'all';
use Test::More;
use Test::Exception;
use LibreCat load => (layer_paths => [qw(t/layer)]);

my $pkg;

BEGIN {
    $pkg = 'LibreCat::FetchRecord::inspire';
    use_ok $pkg;
}

require_ok $pkg;

my $x;

lives_ok {$x = $pkg->new()} 'lives_ok';

can_ok $pkg, $_ for qw(fetch);

SKIP: {

    unless ($ENV{NETWORK_TEST}) {
        skip("No network. Set NETWORK_TEST to run these tests.", 5);
    }

    my $pub = $x->fetch('1496182');

    ok $pub , 'got a publication';

    is $pub->[0]{title},
        'Quantum scattering in one-dimensional systems satisfying the minimal length uncertainty relation',
        'got a title';
    is $pub->[0]{type}, 'journal_article', 'type == journal_article';

    $pub = $x->fetch('123456789876543212345');

    ok !$pub, "empty record";
}

done_testing;
