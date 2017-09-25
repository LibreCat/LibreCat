use strict;
use warnings;

use Path::Tiny;
use lib path(__FILE__)->parent->parent->child('lib')->stringify;
use LibreCat load => (layer_paths => [qw(t/layer)]);

use Test::More import => ['!pass'];
use Test::WWW::Mechanize::PSGI;

my $app = eval {require 'bin/app.pl';};

my $mech = Test::WWW::Mechanize::PSGI->new(app => $app);

subtest 'sru' => sub {
    $mech->get_ok('/sru');
    $mech->content_like(qr/explainResponse/);

    $mech->get_ok('sru?version=1.1&operation=searchRetrieve&query=einstein');
    $mech->content_like(qr/\<numberOfRecords\>/);
};

subtest '/oai' => sub {
    $mech->get_ok('/oai');
    $mech->content_like(qr/OAI-PMH/);

    $mech->content_like(qr/illegal OAI verb/);
    $mech->get_ok('/oai?verb=Identify');
    $mech->content_like(qr/\<repositoryName\>/);
};

done_testing;
