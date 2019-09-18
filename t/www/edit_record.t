use strict;
use warnings;

use Path::Tiny;
use lib path(__FILE__)->parent->parent->child('lib')->stringify;
use LibreCat -load => {layer_paths => [qw(t/layer)]};

use Test::More import => ['!pass'];
use Test::WWW::Mechanize::PSGI;

my $app = eval {do './bin/app.pl';};

my $mech = Test::WWW::Mechanize::PSGI->new(app => $app);

subtest "login" => sub {
    $mech->get_ok('/login');

    $mech->submit_form_ok(
        {
            form_number => 1,
            fields      => {user => "einstein", pass => "einstein"},
        },
        'submitting the login form'
    );

    $mech->content_contains("(Admin)", "logged in successfully");
};

subtest "edit record" => sub {
    $mech->get_ok('/librecat/record/edit/2737383');

    $mech->has_tag('h1',
        'Function of glutathione peroxidases in legume root nodules');

    $mech->submit_form_ok(
        {
            form_id => 'edit_form',
            button  => 'finalSubmit',
            fields  => {

            },
        },
        'submitting the login form'
    );

    $mech->content_contains("(Admin)", "logged in successfully");
};

subtest "clone record" => sub {
    $mech->get_ok('/librecat/record/clone/2737383');

    $mech->has_tag('h1',
        'Function of glutathione peroxidases in legume root nodules');

    $mech->submit_form_ok(
        {
            form_id => 'edit_form',
            button  => 'finalSubmit',
            fields  => {

            },
        },
        'submitting the login form'
    );

    $mech->content_contains("(Admin)", "logged in successfully");
};

done_testing;
