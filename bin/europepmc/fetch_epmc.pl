#!/usr/bin/env perl

use Catmandu::Sane;
use Catmandu::Importer::JSON;
use Catmandu::Exporter::JSON;
use Catmandu::Importer::getJSON;
use POSIX qw/ceil/;
use Getopt::Long;

my ($source, $initial, $verbose);
GetOptions(
    "source=s" => \$source,
    "initial" => \$initial,
    "verbose"  => \$verbose,
    )
    or die("Error in command line arguments\n");

my $initial_exp = Catmandu::Exporter::JSON->new(file => "epmc_pub.json");

if ($initial) {
    Catmandu::Importer::JSON->new(file => 'pub.json')->each(sub {

      my $input = $_[0]->{export};
      next unless $input->{pmid};

      print STDERR "fetching: $input->{pmid}\n";
      Catmandu::Importer::getJSON->new(
        from  => "http://www.ebi.ac.uk/europepmc/webservices/rest/search/query=$input->{pmid}&format=json"
        )->each(sub {

          my ($record) = @_;
          $initial_exp->add($record);

        });

    });
} elsif (!$source) {
    die "No source provided.";
}

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
    } elsif ($source eq 'dblinks') {
        $go = (lc $input->{hasDbCrossReferences} eq 'y') ? 1 : 0;
    }
    next unless $go;
    my $pages = 1;

    print STDERR "fetching $source: $input->{id}\n";

    if ($source eq 'dblinks') {
        my $dbs = $input->{dbCrossReferenceList}->{dbName};
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
