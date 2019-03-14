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

note("import bibtext");
{
    $mech->get_ok('/librecat/record/new');

    $mech->has_tag('h1','Add New Publication');

    my $bibtex =<<EOF;
\@article{article,
  author  = {Peter Adams},
  title   = {The title of the work},
  journal = {The name of the journal},
  year    = 1993,
  number  = 2,
  pages   = {201-213},
  month   = 7,
  note    = {An optional note},
  volume  = 4
}
EOF

    $mech->submit_form_ok(
        {
            form_id => 'bibtex_import_form',
            button  => 'finalSubmit',
            fields  => {
                source => 'bibtex' ,
                data => $bibtex
            },
        },
        'submitting the login form'
    );

    $mech->content_contains("Imported 1 record(s) from bibtex");
}

done_testing;
