#!/usr/local/bin/perl

use lib qw(/srv/www/sbcat/lib /srv/www/sbcat/lib/extension /srv/www/sbcat/lib/default /home/bup/perl5/lib/perl5);
use lib qw(/srv/www/app-catalog/lib);
use Catmandu::Sane;
use Catmandu -all;
use Getopt::Std;
use Data::Dumper;

getopts('u:m:i:');
our $opt_u;
# m for multiple indices
our $opt_m;
our $opt_i;

my $index_name = "backend";
if ( $opt_m ) {
	if ($opt_m eq "backend1" || $opt_m eq "backend2" ) {
		$index_name = $opt_m;
	} else {
		die "$opt_m is not an valid option";
	}
}

Catmandu->load(':up');
my $conf = Catmandu->config;
my $mongoBag = Catmandu->store('authority')->bag('admin');
my $userBag = Catmandu->store('authority')->bag('user');
my $bag = Catmandu->store('search', index_name => $index_name)->bag('researcher');

my $pre_fixer = Catmandu::Fix->new(fixes => [
			'add_num_of_publs()',
			#'copy_field("_id","oId")',
		]);

sub add_to_index {
	my $rec = shift;

	$pre_fixer->fix($rec);
	#print Dumper $rec;
  	my $response = $bag->add($rec);
  	#print Dumper $response;
}


if ($opt_i){
	my $researcher_admin = $mongoBag->get($opt_i);
	my $researcher_user = $userBag->get($opt_i);

	my @fields = qw(full_name old_full_name last_name old_last_name first_name old_first_name email department super_admin reviewer dataManager);
	map {
		$researcher_user->{$_} = $researcher_admin->{$_} if $researcher_admin->{$_};
	} @fields;
	add_to_index($researcher_user) if $researcher_user;
	#print Dumper $researcher_user;
}
else { # initial indexing

	my $allResearchers = $mongoBag->to_array;
	foreach my $researcher_admin (@$allResearchers){
		my $researcher_user = $userBag->get($researcher_admin->{_id});
		my @fields = qw(full_name old_full_name last_name old_last_name first_name old_first_name email department super_admin reviewer dataManager);
		map {
			$researcher_user->{$_} = $researcher_admin->{$_} if $researcher_admin->{$_};
		} @fields;
		add_to_index($researcher_user) if $researcher_user;
		#print Dumper $researcher_user;
	}
}

$bag->commit;

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
