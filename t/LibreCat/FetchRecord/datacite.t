use strict;
use warnings FATAL => 'all';
use Test::More;
use Test::Exception;
use LibreCat load => (layer_paths => [qw(t/layer)]);

my $pkg;

BEGIN {
    $pkg = 'LibreCat::FetchRecord::datacite';
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

    my $pub = $x->fetch('10.6084/M9.FIGSHARE.94301.V1');

    ok $pub , 'got a publication';

    is $pub->[0]{title},
        'Gravity as Entanglement, and Entanglement as Gravity', 'got a title';
    is $pub->[0]{type}, 'research_data', 'type == research_data';

    $pub = $x->fetch('10.23432/3432');

    ok !$pub, "empty record";
}

done_testing;
