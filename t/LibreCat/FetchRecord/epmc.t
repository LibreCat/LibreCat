use strict;
use warnings FATAL => 'all';
use Test::More;
use Test::Exception;

use Path::Tiny;
use lib path(__FILE__)->parent->parent->child('lib')->stringify;
use LibreCat qw(:load);

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

    is $pub->{title} , 'Numerical Evidence for a Phase Transition in 4D Spin-Foam Quantum Gravity.' , 'got a title';
    is $pub->{type} , 'journal_article', 'type == journal_article';
}

done_testing;
