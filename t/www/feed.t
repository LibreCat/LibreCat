use strict;
use warnings;

use Path::Tiny;
use lib path(__FILE__)->parent->parent->child('lib')->stringify;
use LibreCat load => (layer_paths => [qw(t/layer)]);

use Test::More;
use Test::WWW::Mechanize::PSGI;

my $app = eval {require 'bin/app.pl';};

my $mech = Test::WWW::Mechanize::PSGI->new(app => $app);

subtest 'feed' => sub {
    $mech->get_ok('/feed');
    $mech->content_like(qr/\<syn:updateBase/);

    $mech->get_ok('/feed/whatever');
};

subtest 'feed \w period' => sub {
    $mech->get_ok('/feed/daily');
    $mech->get_ok('/feed/weekly');
    $mech->get_ok('/feed/monthly');
};

done_testing;
