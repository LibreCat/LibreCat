use strict;
use warnings;

use Path::Tiny;
use lib path(__FILE__)->parent->parent->child('lib')->stringify;
use LibreCat load => (layer_paths => [qw(t/layer)]);

use Test::More;
use Test::WWW::Mechanize::PSGI;

my $app = eval {
    require 'bin/app.pl';
};

my $mech = Test::WWW::Mechanize::PSGI->new(app => $app);

note("data publications");
{
    $mech->get_ok( '/data' );

    # check if all links work
    $mech->page_links_ok('testing all the links');
}

done_testing;
