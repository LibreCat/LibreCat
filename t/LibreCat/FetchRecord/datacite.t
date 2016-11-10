use strict;
use warnings FATAL => 'all';
use Test::More;
use Test::Exception;

use Path::Tiny;
use lib path(__FILE__)->parent->parent->child('lib')->stringify;
use LibreCat qw(:load);

my $pkg;

BEGIN {
    $pkg = 'LibreCat::FetchRecord::datacite';
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

    my $pub = $x->fetch('10.6084/M9.FIGSHARE.94301.V1');

    ok $pub , 'got a publication';

    is $pub->{title} , 'Gravity as Entanglement, and Entanglement as Gravity' , 'got a title';
    is $pub->{type} , 'research_data', 'type == research_data';
}

done_testing;
