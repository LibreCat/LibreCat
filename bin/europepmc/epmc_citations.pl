#!/usr/bin/env perl

use Catmandu::Sane;
use Catmandu::Importer::JSON;
use Catmandu::Exporter::JSON;
use Catmandu::Importer::getJSON;
use POSIX qw/ceil/;

my $source = $ARGV[0];

exit unless $source;

my $exporter = Catmandu::Exporter::JSON->new(file => "$source.json");

Catmandu::Importer::JSON->new(file => 'epmc_pub.json')->each(

sub {
    my $input = $_[0]->{resultList}->{result}->[0];
    my $go;
    my $dbs;
    if($source eq 'citations') {
        $go = $input->{citedByCount} || 0;
    } elsif ($source eq 'references') {
        $go = (lc $input->{hasReferences} eq 'y') ? 1 : 0;
    } elsif ($source eq 'db_xrefs') {
        $go = (lc $input->{hasDbCrossReferences} eq 'y') ? 1 : 0;
    }
    next unless $go;
    my $pages = 1;

    print STDERR "fetching $source: $input->{id}\n";

    if ($source eq 'db_xrefs') {
        my $dbs = $input->{dbCrossReferenceList}->{dbName};
        #$dbs = (ref $dbs eq 'ARRAY') ? $dbs : [$dbs];
        foreach my $db (@{$dbs}) {
            Catmandu::Importer::getJSON->new(
                from => "http://www.ebi.ac.uk/europepmc/webservices/rest/MED/$input->{id}/databaseLinks/$db/1/json"
            )->each(sub{
                my ($record) = @_;
                $exporter->add($record);
            });
        }
    } else {
        my $p = 1;
        while ($p <= $pages) {
            Catmandu::Importer::getJSON->new(
                from => "http://www.ebi.ac.uk/europepmc/webservices/rest/MED/$input->{id}/$source/$p/json"
            )->each(
            sub {
                my ($record) = @_;
                $pages = ceil ($record->{hitCount}/25) if $p == 1;
                $exporter->add($record);
            });

            $p++;
        }
    }
});
