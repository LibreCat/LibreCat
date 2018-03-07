use strict;
use warnings;
use Path::Tiny;
use lib path(__FILE__)->parent->parent->child('lib')->stringify;
use LibreCat load => (layer_paths => [qw(t/layer)]);
use Test::More import => ['!pass'];
use Test::WWW::Mechanize::PSGI;

my $app = eval {require 'bin/app.pl';};

my $mech = Test::WWW::Mechanize::PSGI->new(app => $app);

subtest 'person overview page' => sub {
    $mech->get_ok('/person');
    $mech->page_links_ok('testing all the links');
};

subtest 'person list alphabetical index' => sub {
    $mech->get_ok('/person?browse=a');
    $mech->get_ok('/person?browse=A');


    $mech->get_ok('/person?browse=E');
    $mech->content_unlike(qr/Einstein,, Albert/);

    $mech->get_ok('/person?browse=P');
    $mech->content_like(qr/Portman, Natalie/);
    $mech->content_unlike(qr/Presley, Elvis/);
};

subtest 'person profile with single digit id' => sub {
    $mech->get_ok('/person/1');
    $mech->content_like(qr/Test User/);
    $mech->get_ok('/person/1/data');
};

subtest 'person profile with id' => sub {
    $mech->get_ok('/person/1234');
    $mech->content_like(qr/Albert Einstein/);
    $mech->get_ok('/person/1234/data');
};

subtest 'person profile with alias' => sub {
    $mech->get_ok('/person/genius');
    $mech->content_like(qr/Albert Einstein/);
    $mech->get_ok('/person/genius');
};

subtest 'staffdirectory' => sub {
    $mech->get_ok('/staffdirectory/1234');
};

done_testing;
