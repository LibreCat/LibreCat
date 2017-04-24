use strict;
use warnings;

use Test::More;
use Test::WWW::Mechanize::PSGI;

my $app = eval {
    require 'bin/app.pl';
};

my $mech = Test::WWW::Mechanize::PSGI->new(app => $app);


note("departments");
{
    $mech->get_ok( '/department' );

    # check if all links work
    $mech->page_links_ok('testing all the links');
}

done_testing;
