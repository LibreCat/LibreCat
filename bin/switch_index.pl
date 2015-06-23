#!/usr/bin/env perl

use Catmandu::Sane;
use Catmandu -load;
use Search::Elasticsearch;
use Catmandu::Importer::JSON;
use Data::Dumper;

Catmandu->load(':up');
Catmandu->config;

my $backup_store = Catmandu->store('backup');

my $e = Search::Elasticsearch->new();

my $pub1_exists = $e->indices->exists(index => 'pub1');
my $pub2_exists = $e->indices->exists(index => 'pub2');

sub _do_switch {
	my ($old, $new) = @_;

	print "Index $old exists, new index will be $new.\n";

	my $store = Catmandu->store('search', index_name => $new);
	my @bags = qw(publication project award researcher department);
	foreach my $b (@bags) {
		my $bag = $store->bag($b);
		$bag->add_many($backup_store->bag($b));
		$bag->commit;
	}

	print "New index is $new. Testing...\n";
	my $checkForIndex = $e->indices->exists(index => $new);
	if($checkForIndex){
		print "Index $new exists. Setting index alias 'pub' to $new, testing and then deleting index $old.\n";

		$e->indices->update_aliases(
		    body => {
		    	actions => [
		    	    { add    => { alias => 'pub', index => $new }},
		    	    { remove => { alias => 'pub', index => $old }}
		    	]
		    }
		);

		$checkForIndex = $e->indices->exists(index => 'pub');

		if($checkForIndex){
			print "Alias 'pub' is ok and points to index $new. Deleting $old.\n";
			$e->indices->delete(index => $old);
		}
		else {
			print "Error: Could not create alias.\n";
			exit;
		}
	}
	else {
		print "Error: Could not create index $new.\n";
		exit;
	}
}

# main
if (($pub1_exists and !$pub2_exists) or (!$pub1_exists and !$pub2_exists)) {

	_do_switch('pub1','pub2');

} elsif ($pub2_exists and !$pub1_exists) {

	_do_switch('pub2','pub1');

} else { # $pub1_exists and $pub2_exists

	print "Both indexes exist. Find out which one is running \n
	(curl -s -XGET 'http://localhost:9200/[alias]/_status') and delete \n
	the other (curl -s -XDELETE 'http://localhost:9200/[unused_index]').\n Then restart!\n";
	exit;

}
