#!/usr/bin/env perl

use lib qw(/home/bup/pub);

#use lib qw(/srv/www/sbcat/lib /srv/www/sbcat/lib/extension /srv/www/sbcat/lib/default /home/bup/perl5/lib/perl5);
#use lib qw(/srv/www/app-catalog/lib);

use Catmandu::Sane;
use Catmandu -all;
use Getopt::Std;
use Data::Dumper;
use Catmandu::Store::MongoDB;

getopts('u:m:i:');
our $opt_u;
# m for multiple indices
our $opt_m;
our $opt_i;

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

my $mongoBag = Catmandu::Store::MongoDB->new(database_name => 'authority_new');
my $bag = Catmandu->store('search', index_name => $index_name)->bag('researcher');

my $pre_fixer = Catmandu::Fix->new(fixes => [
			'add_num_of_publs()',
			#'remove_field("type")',
			#'remove_field("personTitle")',
			#'remove_field("_version")',
			#'copy_field("_id","oId")',
		]);

#sub add_to_index {
#	my $rec = shift;
#	$pre_fixer->fix($rec);
#  	my $response = $bag->add($rec);
#}


if ($opt_i){
    my $researcher = $mongoBag->get($opt_i);
	#add_to_index($researcher) if $researcher;
	$pre_fixer->fix($researcher);
  	$bag->add($researcher);
}
else { # initial indexing

	my $allResearchers = $mongoBag->to_array;
	my $researchers;
	my $i = 1;
	foreach my $researcher (@$allResearchers){

#		next if ($researcher->{type} and $researcher->{type} eq "organization");
#		next if $researcher->{name_lc};
#		next if !$researcher->{first_name};
		if((!$researcher->{type} or $researcher->{type} and $researcher->{type} ne "organization") and !$researcher->{name_lc} and $researcher->{first_name}){
			$pre_fixer->fix($researcher);
			$bag->add($researcher);
			
			my $result = `curl -I -s pub3.ub.uni-bielefeld.de/publication`;
			if($result !~ /HTTP\/1.1 200 OK/){
				print Dumper $researcher;
				print Dumper $i;
				exit;
			}
			$i++;
		}

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
