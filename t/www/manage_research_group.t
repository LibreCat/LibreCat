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

note("manage research group");
{
    $mech->get_ok( '/librecat/admin/research_group');

    $mech->has_tag('h1','Manage Research Groups');
}

note("search research group");
{
    $mech->submit_form_ok( {
                form_id => 'admin-research-group-search',
                fields  => {
                    q => ""
                },
            }, 'submitting the search form ""'
    );

    $mech->content_contains("Results", "Results");
}

note("adding research group");
{
    $mech->get_ok('/librecat/admin/research_group/new');

    $mech->has_tag('h1','Add new Research Group');

    $mech->submit_form_ok( {
                form_id => 'id_research_group_form',
                fields  => {
                    name => "test group"
                },
            }, 'submitting the add form'
    );

    $mech->content_contains("Results", "found results");
}

done_testing;
