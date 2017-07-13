use strict;
use warnings;

use Path::Tiny;
use lib path(__FILE__)->parent->parent->child('lib')->stringify;
use LibreCat load => (layer_paths => [qw(t/layer)]);

use Test::More;
use Test::WWW::Mechanize::PSGI;

my $app = eval {require 'bin/app.pl';};

my $mech = Test::WWW::Mechanize::PSGI->new(app => $app);

subtest 'department overview page' => sub {
    $mech->get_ok('/department');
    $mech->page_links_ok('testing all the links');

    $mech->content_like(qr/(?i)department of mathematics/);
};

done_testing;
