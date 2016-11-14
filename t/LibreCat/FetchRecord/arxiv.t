use strict;
use warnings FATAL => 'all';
use Test::More;
use Test::Exception;
use LibreCat load => (layer_paths => [qw(t/layer)]);

my $pkg;

BEGIN {
    $pkg = 'LibreCat::FetchRecord::arxiv';
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

    my $pub = $x->fetch('arXiv:1609.01725');

    ok $pub , 'got a publication';

    is $pub->{title} , 'The Good, the Bad, and the Ugly of Gravity and Information' , 'got a title';
    is $pub->{type} , 'preprint', 'type == preprint';
}

done_testing;
