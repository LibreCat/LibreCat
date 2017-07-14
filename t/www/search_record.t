use strict;
use warnings;

use Path::Tiny;
use LibreCat load => (layer_paths => [qw(t/layer)]);

use Test::More;
use Test::WWW::Mechanize::PSGI;

my $app = eval {require 'bin/app.pl';};

my $mech = Test::WWW::Mechanize::PSGI->new(app => $app);

note("search: Peeters Netherlands");
{
    $mech->get_ok('/publication?q=Peeters+Netherlands');

    # title is now in german, because we don't have language detection
    $mech->has_tag('h1', 'Publications at LibreCat University');

    # check if all links work
    $mech->content_contains('Regime change at a distance:',
        'got the right result');
}

note("search: Netherlands");
{
    $mech->get_ok('/publication?q=Netherlands');

    # title is now in german, because we don't have language detection
    $mech->has_tag('h1', 'Publications at LibreCat University');

    # check if all links work
    $mech->content_contains('Regime change at a distance:',
        'got the right result');
}

note("search: Markovic, Dida space");
{
    $mech->get_ok('/publication?q=Markovic%2C+Dida+space#');

    # title is now in german, because we don't have language detection
    $mech->has_tag('h1', 'Publications at LibreCat University');

    # check if all links work
    $mech->content_contains(
        'Large-scale retrospective relative spectro-photometric self-calibration in space',
        'got the right result'
    );
}

done_testing;
