#!/usr/bin/env perl

use Catmandu::Sane;
use Catmandu -load;
use Catmandu::Importer::JSON;
use Catmandu::Fix qw/epmc_dblinks/;
use YAML;
use Getopt::Long;

my ($mod,$verbose);
GetOptions ("mod=s" => \$mod,
            "verbose"  => \$verbose)
or die("Error in command line arguments\n");

Catmandu->load(':up');

my $bag = Catmandu->store('metrics')->bag('$mod');

my $imp = Catmandu::Importer::JSON->new(file => "$mod.json");
my $rec;

sub _cit_ref {
    my $item = shift;

    my $pmid = $item->{request}->{id};
    $rec->{$pmid}->{_id} = $pmid;
    $rec->{$pmid}->{total} = $item->{hitCount};

    my $entries;
    if ($mod eq 'citations') {
        $entries = $item->{citationList}->{citation};
    } elsif ($mod eq 'references') {
        $entries = $item->{referenceList}->{reference};
    }

    foreach my $e (@{$entries}) {
        push @{$rec->{$pmid}->{entries}}, $e;
    }

}

sub _db_xrefs {
    my $item = shift;

    my $pmid = $item->{request}->{id};
    my $db_item = $item->{dbCrossReferenceList}->{dbCrossReference}->[0];
    my $db_name = $db_item->{dbName};

    my $db_fixer = Catmandu::Fix->new(fixes => ["epmc_dblinks($db_name)"]);
    my $fixed_db = $db_fixer->fix($db_item);

    $rec->{$pmid}->{_id} = $pmid;
    $rec->{$pmid}->{db}->{$db_name}->{total} = $db_item->{dbCount};
    $rec->{$pmid}->{db}->{$db_name}->{entries} = $fixed_db;

}

# main
$imp->each(sub{
    my $item = $_[0];
    next if $item->{errMsg};

    if ($mod eq 'citations' or $mod eq 'references') {
        _cit_ref($item);
    } elsif ($mod eq 'db_xref') {
        _db_xref($item);
    }
});

foreach my $k (keys %$rec) {
    $bag->add($rec->{$k});
}

print "Done\n";
