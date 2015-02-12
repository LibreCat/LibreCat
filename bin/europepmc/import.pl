#!/usr/bin/env perl

use Catmandu::Sane;
use Catmandu -load;
use Catmandu::Importer::JSON;
#use Catmandu::Store::Hash;
use Catmandu::Fix qw/epmc_dblinks/;
use Data::Dumper;
use Getopt::Long;

my ($mod,$verbose);
GetOptions ("mod=s" => \$mod,
#            "references"   => \$references,
            "verbose"  => \$verbose)
or die("Error in command line arguments\n");
print $mod;
#exit;
Catmandu->load;

my $bag = catmandu->store('metrics')->bag('$mod');
#my $bag = Catmandu::Store::Hash->new();
#$bag->delete_all;

my $imp = Catmandu::Importer::JSON->new(file => "citations.json");

$imp->each(sub{
    my $item = $_[0];
    my $rec;
    $rec = $bag->get($item->{_id}); # no matter if it matches or not.

    $rec->{_id} = $item->{request}->{id};
    $rec->{total} = $item->{hitCount};

    my $entries;
    if ($mod eq 'citations') {
        $entries = $item->{citationList}->{citation};
    } elsif ($mod eq 'references') {
        $entries = $item->{referenceList}->{reference};
    }
    foreach my $e (@{$entries}) {
        #print Dumper $e;
        push @{$rec->{entries}}, $e;
    }
    print Dumper $rec;
});

my $db_fixer = Catmandu::Fix->new(fixes => ['epmc_dblinks()']);

print "Done\n";
