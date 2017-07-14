use strict;
use warnings;

use Path::Tiny;
use lib path(__FILE__)->parent->parent->child('lib')->stringify;
use LibreCat load => (layer_paths => [qw(t/layer)]);

use Test::More;
use Test::WWW::Mechanize::PSGI;

my $app = eval {require 'bin/app.pl';};

my $mech = Test::WWW::Mechanize::PSGI->new(app => $app);

subtest 'project splash page' => sub {
    $mech->get_ok('/project/PDR07/93');
    $mech->page_links_ok('testing all the links');

    $mech->get_ok('/project/41K03404');
    $mech->page_links_ok('testing all the links');
};

subtest 'project index page' => sub {
    $mech->get_ok('/project');
    $mech->get_ok('/project/');

    $mech->page_links_ok('testing all the links');
};

subtest 'browsing projects' => sub {
    $mech->get_ok('/project?browse=a');
    $mech->page_links_ok('testing all the links');

    $mech->get_ok('/project?browse=i');
    $mech->page_links_ok('testing all the links');
};

done_testing;
