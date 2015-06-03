#!/usr/bin/env perl

use Catmandu::Sane;
use Catmandu -load;
use Getopt::Std;
use Catmandu::Store::MongoDB;
use Catmandu::Exporter::JSON;

getopts('i:');
our $opt_i;

Catmandu->load(':up');
my $conf = Catmandu->config;

my $mongoBag = Catmandu::Store::MongoDB->new(database_name => 'authority_new');
my $bag = Catmandu->store('search', index_name => 'pub')->bag('researcher');

my $fixer = Catmandu::Fix->new(fixes => ['add_num_of_publs()']);

if ($opt_i){
    my $researcher = $mongoBag->get($opt_i);
	$fixer->fix($researcher);
  	$bag->add($researcher);
	$bag->commit;
}
else { # initial indexing
	$fixer->fix($mongoBag);
	my $exp = Catmandu::Exporter::JSON->new(file => 'authority.json');
	$exp->add_many($mongoBag);
}

=head1 SYNOPSIS

Script for indexing researchers data

=head2 Initial indexing

perl index_researcher.pl

# fetches all data from project mongodb and pushes it into the search store

=head2 Update process

perl index_researcher.pl -i 'ID'

=cut
