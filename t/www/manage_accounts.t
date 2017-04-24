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

note("login");
{
    $mech->get_ok( '/login' );

    $mech->submit_form_ok( {
                form_number => 1,
                fields      => {
                    user => "einstein",
                    pass => "einstein"
                },
            }, 'submitting the login form'
    );

    $mech->content_contains("(Admin)", "logged in successfully");
}

note("manage accounts");
{
    $mech->get_ok( '/librecat/admin/account');

    $mech->has_tag('h1','Manage Account Information');
}

note("search accounts");
{
    $mech->submit_form_ok( {
                form_id => 'admin-account-search',
                fields  => {
                    q => ""
                },
            }, 'submitting the search form ""'
    );

    $mech->content_contains("2 Results", "found 2 results");


    $mech->submit_form_ok( {
                form_id => 'admin-account-search',
                fields  => {
                    q => "albert einstein"
                },
            }, 'submitting the search form "albert einstein"'
    );

    $mech->content_contains("1 Results", "found 1 results");

    $mech->submit_form_ok( {
                form_id => 'admin-account-search',
                fields  => {
                    q => "einstein, albert"
                },
            }, 'submitting the search form "einstein, albert"'
    );

    $mech->content_contains("1 Results", "found 1 results");


    $mech->submit_form_ok( {
                form_id => 'admin-account-search',
                fields  => {
                    q => "albert"
                },
            }, 'submitting the search form "albert"'
    );

    $mech->content_contains("1 Results", "found 1 results");
}

note("editing account");
{
    $mech->submit_form_ok( {
                form_id => 'admin-account-search',
                fields  => {
                    q => "test"
                },
            }, 'submitting the search form "albert"'
    );

    $mech->content_contains("1 Results", "found 1 results");

    $mech->follow_link_ok( { url => '/librecat/admin/account/edit/4321'}  , 'follow edit link');

    $mech->content_contains("Edit Account for User, Test", "found the correct user");

    $mech->submit_form_ok( {
                form_id => 'id_account_form',
                fields  => {
                },
            }, 'submitting the edit form'
    );

    $mech->has_tag('h1','Manage Account Information');
}

done_testing;
