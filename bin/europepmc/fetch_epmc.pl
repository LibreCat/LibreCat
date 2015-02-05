#!/usr/bin/env perl

use Catmandu::Sane;
use Catmandu::Importer::JSON;
use Catmandu::Exporter::JSON;
use Catmandu::Importer::getJSON;

my $exporter = Catmandu::Exporter::JSON->new(file => 'epmc_pub.json');

Catmandu::Importer::JSON->new(file => 'test.json')->each(sub {

  my $input = $_[0]->{export};
  next unless $input->{pmid};

  print STDERR "fetching: $input->{pmid}\n";
  Catmandu::Importer::getJSON->new(
    from  => "http://www.ebi.ac.uk/europepmc/webservices/rest/search/query=$input->{pmid}&format=json"
    )->each(sub {

      my ($record) = @_;
      $exporter->add($record);

    });

});
