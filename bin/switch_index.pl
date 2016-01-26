#!/usr/bin/env perl

use Catmandu::Sane;
use Catmandu -load;
use Search::Elasticsearch;
use Catmandu::Importer::JSON;
use Data::Dumper;
use Fcntl qw(:flock);

open(SELF, "<", $0) or die "Cannot open $0 - $!";

flock(SELF, LOCK_EX|LOCK_NB) or die "Script is already running";

Catmandu->load(':up');

my $ind_name = Catmandu->config->{store}->{search}->{options}->{'index_name'};
my $ind1 = $ind_name ."1";
my $ind2 = $ind_name ."2";

my $backup_store = Catmandu->store('backup');

my $e = Search::Elasticsearch->new();

my $ind1_exists = $e->indices->exists(index => $ind1);
my $ind2_exists = $e->indices->exists(index => $ind2);

sub _do_switch {
	my ($old, $new) = @_;

	print "Index $old exists, new index will be $new.\n";

	my $store = Catmandu->store('search', index_name => $new);
	my @bags = qw(publication project award researcher department research_group);
	foreach my $b (@bags) {
		my $bag = $store->bag($b);
		$bag->add_many($backup_store->bag($b));
		$bag->commit;
	}

	print "New index is $new. Testing...\n";
	my $checkForIndex = $e->indices->exists(index => $new);
	if($checkForIndex){
		print "Index $new exists. Setting index alias $ind_name to $new, testing and then deleting index $old.\n";

		$e->indices->update_aliases(
		    body => {
		    	actions => [
		    	    { add    => { alias => $ind_name, index => $new }},
		    	    { remove => { alias => $ind_name, index => $old }}
		    	]
		    }
		);

		$checkForIndex = $e->indices->exists(index => $ind_name);

		if($checkForIndex){
			print "Alias $ind_name is ok and points to index $new. Deleting $old.\n";
			$e->indices->delete(index => $old);
		}
		else {
			print "Error: Could not create alias $ind_name.\n";
			exit;
		}
	}
	else {
		print "Error: Could not create index $new.\n";
		exit;
	}
}

# main
if (($ind1_exists and !$ind2_exists) or (!$ind1_exists and !$ind2_exists)) {

	_do_switch($ind1, $ind2);

} elsif ($ind2_exists and !$ind1_exists) {

	_do_switch($ind2, $ind1);

} else { # $pub1_exists and $pub2_exists

	print "Both indexes exist. Find out which one is running \n
	(curl -s -XGET 'http://localhost:9200/[alias]/_status') and delete \n
	the other (curl -s -XDELETE 'http://localhost:9200/[unused_index]').\n Then restart!\n";
	exit;

}
