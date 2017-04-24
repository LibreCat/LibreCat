use strict;
use warnings;

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

done_testing;
