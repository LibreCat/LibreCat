use strict;
use warnings FATAL => 'all';
use Test::More;
use Test::Exception;
use LibreCat load => (layer_paths => [qw(t/layer)]);
use Data::Dumper;

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

    subtest 'one_publication' => sub {
        my $pub = $x->fetch('arXiv:1609.01725');

        ok $pub , 'got a publication';

        like $pub->[0]->{title} , qr/Ugly of Gravity/, 'got correct title';
        is $pub->[0]->{type} , 'preprint', 'type == preprint';
    };

    subtest 'orcid' => sub {
        my $pub = $x->fetch('0000-0002-7970-7855');

        ok $pub , 'got some publications';
        ok $pub->[0];
        ok $pub->[1];
        is $pub > 4, 1, 'more than one publication'
    };

    subtest 'empty' => sub {
        my $pub = $x->fetch('arXvi:sldkfjaslkdfjasödilfusaor');

        ok !$pub;
    };
}

done_testing;
