use strict;
use warnings;

use Path::Tiny;
use lib path(__FILE__)->parent->parent->child('lib')->stringify;
use LibreCat -load => {layer_paths => [qw(t/layer)]};

use Test::More import => ['!pass'];
use Test::WWW::Mechanize::PSGI;

my $app = eval {do './bin/app.pl';};

my $mech = Test::WWW::Mechanize::PSGI->new(app => $app);

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

note("add / get message");
{
    $mech->get_ok('/librecat');

    $mech->submit_form_ok(
        {
            form_id => 'message_form',
            fields =>
                {record_id => 1, user_id => 1234, message => "Test message."},
        },
        'submitting the message form'
    );

    $mech->content_contains("(Admin)", "back on dashboard");

    $mech->get_ok('/librecat/message/1');

    $mech->content_like(qr(Test message));
}

done_testing;
