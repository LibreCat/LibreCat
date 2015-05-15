#!/usr/bin/env perl

use Catmandu::Sane;
use Catmandu -all;
use Getopt::Std;
use Data::Dumper;

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

my $mongoBag = Catmandu->store('department');
my $bag = Catmandu->store('search', index_name => $index_name)->bag('department');

my $pre_fixer = Catmandu::Fix->new(fixes => [
			'dept_name()',
			'remove_field("parent")',
			'remove_field("oId")',
			'remove_field("dateLastChanged")',
		]);

sub add_to_index {
	my $rec = shift;

	$pre_fixer->fix($rec);
  	$bag->add($rec);
}


if ($opt_i){
	my $department = $mongoBag->get($opt_i);
	add_to_index($department);
}
else { # initial indexing

	my $allDepartments = $mongoBag->to_array;
	foreach(@$allDepartments){
		add_to_index($_);
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
