#!/usr/local/bin/perl

use lib qw(/srv/www/sbcat/lib /srv/www/sbcat/lib/extension /srv/www/sbcat/lib/default /home/bup/perl5/lib/perl5);
use Catmandu::Sane;
use Catmandu -all;
use Getopt::Std;
use Data::Dumper;

getopts('u:m:i:');
our $opt_u;
# m for multiple indices
our $opt_m;
our $opt_i;

my $home = $ENV{BACKEND};

if($opt_m && $opt_m eq "backend2"){
	Catmandu->load("$home/index2");
}
elsif($opt_m && $opt_m eq "backend1"){
	Catmandu->load("$home/index1");
}
else {
	Catmandu->load;
}

my $conf = Catmandu->config;
my $mongoBag = Catmandu->store('authority')->bag();
my $bag = Catmandu->store('search')->bag('department');

my $pre_fixer = Catmandu::Fix->new(fixes => [
			'department_name()',
		]);

sub add_to_index {
	my $rec = shift;

	$pre_fixer->fix($rec);
  	$bag->add($rec);
}


if ($opt_i){
	my $department = $mongoBag->get($opt_i);
	if($department->{type} eq "organization"){
		add_to_index($department);
	}
	else {
		print "Wrong type!\n";
	}
}
else { # initial indexing

	my $allDepartments = $mongoBag->select("type", "organization")->to_array;
	foreach(@$allDepartments){
		add_to_index($_);
		#print Dumper $_;
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
