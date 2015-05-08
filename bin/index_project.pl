#!/usr/bin/env perl

use lib qw(/home/bup/perl5/lib/perl5);
use Catmandu::Sane;
use Catmandu -all;
use Getopt::Std;
use Data::Dumper;

getopts('u:m:');
our $opt_u;

# m for multiple indices
our $opt_m;

my $home = "/srv/www/pub/";#$ENV{BACKEND};

my $index_name = "pub";
if ( $opt_m ) {
	if ($opt_m eq "pub1" || $opt_m eq "pub2" ) {
		$index_name = $opt_m;
	} else {
		die "$opt_m is not an valid option";
	}
}

Catmandu->load(':up');
my $conf = Catmandu->config;

my $pre_fixer = Catmandu::Fix->new(fixes => [
			'start_end_year_from_date()',
		]);

#my $mongoBag = Catmandu->store('project')->bag;
my $mongoBag = Catmandu::Store::MongoDB->new(database_name => 'PUBProject');
my $projBag = Catmandu->store('search', index_name => $index_name)->bag('project');

if ($opt_u) { # update process
	my $project = $mongoBag->get($opt_u);
	#print Dumper $project;
	$pre_fixer->fix($project);
	($project) ? ($projBag->add($project)) : ($projBag->delete($opt_u));

} else { # initial indexing

	my $allProj = $mongoBag->to_array;
	foreach (@$allProj){
		$pre_fixer->fix($_);
		$projBag->add($_)
	}
	#$projBag->add_many($allProj);

}

$projBag->commit;

=head1 SYNOPSIS

Script for indexing project data

=head2 Initial indexing

perl index_project.pl

# fetches all data from project mongodb and pushes it into the search store

=head2 Update process

perl index_project.pl -u 'ID'

# fetches one record with the id 'ID' and pushes it into the search storej or deletes it if 'ID' not found anymore

=head1 VERSION

0.02, Oct. 2012

=cut
