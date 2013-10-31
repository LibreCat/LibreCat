#!/usr/local/bin/perl

use lib qw(/srv/www/sbcat/lib /srv/www/sbcat/lib/extension);

use Catmandu::Sane;
use Catmandu -all;
use Catmandu::Fix qw(add_ddc rename_relations move_field split_ext_ident add_contributor_info add_file_access language_info remove_field volume_sort);

use MDS;
use SBCatDB;
use luurCfg;
use Getopt::Std;
use Orms;

my $db = SBCatDB->new({
    config_file => "/srv/www/sbcat/conf/extension/sbcatDb.pl",
    db_name  => $orm->{ormsDb},
    host     => $orm->{ormsDbHost},
    username => $orm->{ormsDbUser},
    password => $orm->{ormsDbPassword},
});

my $q = "(submissionStatus exact public OR submissionStatus exact returned) AND dateLastChanged > \"$opt_u\"";
my $results = $db->find($q);

while (my $rec = $results->next) {
	# hi there!
}

