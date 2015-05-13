#!/usr/bin/env perl

use lib qw(/srv/www/sbcat/lib /srv/www/sbcat/lib/extension /srv/www/sbcat/lib/default /home/bup/perl5/lib/perl5);
use Catmandu::Sane;
use Catmandu -all;
use Getopt::Std;
use Catmandu::Store::MongoDB;

getopts('u:m:d');
our $opt_u;
# m for multiple indices
our $opt_m;
our $opt_d;

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

#my $mongoBag = Catmandu->store('award');
my $mongoBag = Catmandu::Store::MongoDB->new(database_name => 'PUBAward');
#my $awardBag = Catmandu->store('award')->bag('award');
my $preisBag = Catmandu->store('search', index_name => $index_name)->bag('award');

if ($opt_d){
	$preisBag->delete_all;
	exit;
}
elsif ($opt_u) { # update process
	my $award = $mongoBag->get($opt_u);
	#print Dumper $award;
	if($award){
		#$award->{id} = $award->{_id};
		#$award->{academyData} = $academyBag->get($award->{academyId}) if $award->{academyId};
		#$award->{academyData}->{id} = $award->{academyData}->{_id} if $award->{academyData};
		#$award->{awardData} = $awardBag->get($award->{award_id}) if $award->{award_id};
		#$award->{awardData}->{id} = $award->{awardData}->{_id} if $award->{awardData};
		$preisBag->add($award);
	}
	else {
		$preisBag->delete($opt_u);
	}

} else { # initial indexing

	my $allAward = $mongoBag->to_array;

	foreach (@$allAward){
		my $aw = $_;
		#$aw->{id} = $aw->{_id};
		# get academy data
		#$aw->{academyData} = $academyBag->get($aw->{academyId}) if $aw->{academyId};
		#$aw->{academyData}->{id} = $aw->{academyData}->{_id} if $aw->{academyData};
		# get award data
		#$aw->{awardData} = $awardBag->get($aw->{award_id}) if $aw->{award_id};
		#$aw->{awardData}->{id} = $aw->{awardData}->{_id} if $aw->{awardData};
		$preisBag->add($aw);
	}

}

$preisBag->commit;

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
