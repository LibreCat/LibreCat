use strict;
use warnings;

use Path::Tiny;
use lib path(__FILE__)->parent->parent->child('lib')->stringify;
use LibreCat -load => {layer_paths => [qw(t/layer)]};

use Test::More import => ['!pass'];
use Test::WWW::Mechanize::PSGI;

my $app = eval {do './bin/app.pl';};

my $mech = Test::WWW::Mechanize::PSGI->new(app => $app);
$mech->max_redirect(0);

note("login fails");
{
    $mech->get("/login");

    $mech->submit_form_ok(
        {
            form_number => 1,
            fields      => {user => "__no_one__", pass => "__no_one__"}
        },
        "submitting the login form with invalid user"
    );

    $mech->content_contains("Wrong username or password");

}

note("login successfull (without return_url)");
{
    $mech->get_ok("/login");

    $mech->submit_form(
        form_number => 1,
        fields      => {user => "einstein", pass => "einstein"}
    );

    is($mech->response->code, 302, "successfull POST /login returns redirect");

    like($mech->response->header("Location"), qr(/librecat), "first redirect after login  goes to /librecat");

    $mech->get($mech->response->header("Location"));

    like($mech->response->header("Location"), qr(/librecat/search/admin), "first redirect after login  goes to /librecat/search/admin");

    $mech->get($mech->response->header("Location"));

    $mech->content_contains("(Admin)", "logged in successfully");

    $mech->get("/logout");
    is($mech->response->code, 302, "successfull logout");
}

note("login successfull (with external return_url)");
{
    $mech->get_ok("/login");

    $mech->submit_form(
        form_number => 1,
        fields      => {
            user => "einstein",
            pass => "einstein",
            return_url => "https://google.be"
        }
    );
    is($mech->response->code, 302, "successfull POST /login returns redirect");

    # return_url was invalid, and replaced by /librecat
    like($mech->response->header("Location"), qr(/librecat), "first redirect after login with invalid return_url goes to /librecat");

    $mech->get("/logout");
    is($mech->response->code, 302, "successfull logout");
}

note("login successfull (with internal return_url)");
{
    $mech->get_ok("/login");

    $mech->submit_form(
        form_number => 1,
        fields      => {
            user => "einstein",
            pass => "einstein",
            return_url => "http://localhost:5001/librecat/admin/account"
        }
    );
    is($mech->response->code, 302, "successfull POST /login returns redirect");

    # return_url was valid
    is($mech->response->header("Location"), "http://localhost:5001/librecat/admin/account", "first redirect after login with valid return_url");

    $mech->get("/logout");
    is($mech->response->code, 302, "successfull logout");
}

done_testing;
