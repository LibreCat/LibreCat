use strict;
use warnings;

use Path::Tiny;
use lib path(__FILE__)->parent->parent->child('lib')->stringify;
use LibreCat -load => {layer_paths => [qw(t/layer)]};

use Test::More import => ['!pass'];
use Test::WWW::Mechanize::PSGI;

my $app = eval {do './bin/app.pl';};

my $mech = Test::WWW::Mechanize::PSGI->new(app => $app);

subtest '/record/:id.:fmt' => sub {
    $mech->get_ok('/record/2737384.json');

    $mech->get_ok('/record/2737384.yaml');

    $mech->get_ok('/record/2737384.bibtex');

    $mech->get('/record/2737384.xyz');
    is $mech->status, "406", "status not acceptable";
};

subtest 'invalid format' => sub {
    $mech->get('/export');
    is $mech->status, '406', "status not acceptable";
    $mech->content_like(qr/Parameter fmt is missing/);

    $mech->get('/export?fmt=xyz');
    is $mech->status, '406', "status not acceptable";
    $mech->content_like(qr/not supported/);
};

subtest 'valid formats' => sub {
    $mech->get_ok('/export?q=netherlands&fmt=bibtex');
    $mech->content_like(qr/^\@\w+\{/);

    $mech->get_ok('/export?q=netherlands&fmt=dc');
    $mech->content_like(qr/\<dc:title\>/);

    $mech->get_ok('/export?q=netherlands&fmt=mods');
    $mech->content_like(qr/\<mods version/);
};

subtest 'private records' => sub {
    $mech->get('/record/2737399.json');
    $mech->content_like(qr/^\{\}$|^\[\]$/);

    note("login");
    {
        $mech->get_ok('/login');

        $mech->submit_form_ok(
            {
                form_number => 1,
                fields      => {user => "einstein", pass => "einstein"},
            },
            'submitting the login form'
        );

        $mech->content_contains("(Admin)", "logged in successfully");
    }

    $mech->get_ok('/librecat/export?cql=id=2737399&fmt=bibtex');
    $mech->content_like(qr/^\@\w+\{/), "bibtex format looks good";

};

done_testing;
