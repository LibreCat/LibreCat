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
    $mech->get_ok( '/librecat/admin/project');

    $mech->has_tag('h1','Manage Projects');
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

    $mech->content_contains("1584 Results", "found 1584 Results");

    $mech->submit_form_ok( {
                form_id => 'admin-account-search',
                fields  => {
                    q => "Staphylococcus aureus strains "
                },
            }, 'submitting the search form "Staphylococcus aureus strains "'
    );

    $mech->content_contains("1 Results", "found 1 results");

    $mech->follow_link_ok( { url => '/librecat/admin/project/edit/011D12402'} , "edit project link");

    $mech->content_contains("Edit Project \"Identification and characterization of virulence-associated markers of Staphylococcus aureus strains from rabbits\"", 'got the correct page');

    $mech->submit_form_ok( {
                form_id => 'id_project_form',
                fields  => {
                },
            }, 'submitting the edit form'
    );

    $mech->has_tag('h1','Manage Projects');
}

done_testing;
