use strict;
use warnings FATAL => 'all';
use Test::More;
use Test::Exception;
use LibreCat load => (layer_paths => [qw(t/layer)]);
use Data::Dumper;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::FetchRecord::epmc';
    use_ok $pkg;
}

require_ok $pkg;

my $x;

lives_ok { $x = $pkg->new()} 'lives_ok';

can_ok $pkg, $_ for qw(fetch);

SKIP: {

    unless ($ENV{NETWORK_TEST}) {
        skip("No network. Set NETWORK_TEST to run these tests.", 5);
    }

    my $pub = $x->fetch('PMID: 27740824');

    ok $pub , 'got a publication';

    is $pub->[0]{title} , 'Numerical Evidence for a Phase Transition in 4D Spin-Foam Quantum Gravity.' , 'got a title';
    is $pub->[0]{type} , 'journal_article', 'type == journal_article';

    $pub = $x->fetch('PMID: 12345678998765432123456');

    ok !$pub, "empty record";
}

done_testing;
