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

note("homepage");
{
    $mech->get_ok( '/' );
    $mech->title_is( 'LibreCat' , 'testing title' );
    $mech->has_tag('h1','Publications at LibreCat University');

    # check if all links work
    $mech->page_links_ok('testing all the links');

    # Setting the page back to english
    $mech->get_ok('/set_language?lang=en');
}

note("search results");
{
    $mech->submit_form_ok( {
                form_number => 1,
                fields      => {
                    q => "THINGSTHATDONTMATCHANYTHING"
                },
            }, 'submitting the search form'
    );

    # title is now in german, because we don't have language detection
    $mech->has_tag('h1','Publications at LibreCat University');

    # check if all links work
    $mech->page_links_ok('testing all the links');
}

done_testing;
