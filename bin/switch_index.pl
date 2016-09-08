#!/usr/bin/env perl

BEGIN {
    use Catmandu::Sane;
    use Path::Tiny;
    use lib path(__FILE__)->parent->parent->child('lib')->stringify;
    use LibreCat::Layers;

    LibreCat::Layers->new->load;
};

use Catmandu::Sane;
use Catmandu;
use Search::Elasticsearch;
use Fcntl qw(:flock);

open(SELF, "<", $0) or die "Cannot open $0 - $!";

flock(SELF, LOCK_EX|LOCK_NB) or die "Script is already running";

my $ind_name = Catmandu->config->{store}{search}{options}{'index_name'};
my $ind1 = $ind_name ."1";
my $ind2 = $ind_name ."2";

my $backup_store = Catmandu->store('backup');

my $e = Search::Elasticsearch->new;

my $ind1_exists = $e->indices->exists(index => $ind1);
my $ind2_exists = $e->indices->exists(index => $ind2);

sub _do_switch {
    my ($old, $new) = @_;

    print "Index $new does not exist yet, new index will be $new.\n";

    my $store = Catmandu->store('search', index_name => $new);
    my @bags = qw(publication project award researcher department research_group);
    foreach my $b (@bags) {
        my $bag = $store->bag($b);
        $bag->add_many($backup_store->bag($b));
        $bag->commit;
    }

    print "New index is $new. Testing...\n";
    my $checkForIndex = $e->indices->exists(index => $new);
    my $checkForAlias = $e->indices->exists(index => $ind_name);
    
    if($checkForIndex){
        print "Index $new exists. Setting index alias $ind_name to $new and testing again.\n";
        
        if(!$checkForAlias){
            # First run, no alias present
            $e->indices->update_aliases(
                body => {
                    actions => [
                        { add => { alias => $ind_name, index => $new }},
                    ]
                }
            );
        }
        else {
            $e->indices->update_aliases(
                body => {
                    actions => [
                        { add    => { alias => $ind_name, index => $new }},
                        { remove => { alias => $ind_name, index => $old }}
                    ]
                }
            );
        }

        $checkForIndex = $e->indices->exists(index => $ind_name);

        if($checkForIndex and !$checkForAlias){
            # First run, no old index to be deleted
            print "Alias $ind_name is ok and points to index $new.\n Done!\n";
        }
        elsif($checkForIndex and $checkForAlias) {
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
