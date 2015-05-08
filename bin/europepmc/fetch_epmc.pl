#!/usr/bin/env perl

use Catmandu::Sane;
use Moo;
use MooX::Options;
use Catmandu::Importer::JSON;
use Catmandu::Exporter::JSON;
use Catmandu::Importer::getJSON;
use Catmandu::Fix::trim as => 'trim';
use POSIX qw/ceil/;
use Try::Tiny;
use Data::Dumper;
option initial => (
    is => 'ro',
    short => 'i',
    doc => "Run with this option in first place.",
    );
option verbose => (
    is => 'ro',
    short => 'v',
    doc => "Print details",
    );
option initial_file => (
    is => 'ro',
    format => 's',
    default => sub {'pub.json'},
    doc => "Specify the initial input file, default is 'pub.json' in the pwd.",
    );
option epmc_file => (
    is => 'ro',
    format => 's',
    default => sub {'epmc.json'},
    doc => "Specify the europe pmc file, default is 'epmc.json' in the pwd.",
    );
option source => (
    is => 'ro',
    short => 's',
    format => 's',
    doc => "Possible values are 'citations', 'references' or 'dblinks'.",
    );

sub BUILD {
    my ($self) = @_;
    die "You must provide either the initial flag or a source"
        unless ($self->initial or $self->source);
}

sub _fetch_initial {
    my ($self) = @_;
    my $v = $self->verbose;

    my $exporter = Catmandu::Exporter::JSON->new(file => $self->epmc_file);
    Catmandu::Importer::JSON->new(file => $self->initial_file)->each(sub {
      my $pmid = trim $_[0]->{export}->{pmid};
      try {
          print "Fetch data for $pmid\n" if $v;
          Catmandu::Importer::getJSON->new(
            from  => "http://www.ebi.ac.uk/europepmc/webservices/rest/search/query=$pmid&format=json"
          )->each(sub {
              my ($record) = @_;
              $exporter->add($record);
          });
      } catch {
        print STDERR "Invalid response for $pmid\n" if $v;
      }
    });
}

sub _fetch_source {
    my ($self, $source) = @_;
    my $v = $self->verbose;

    my $exporter = Catmandu::Exporter::JSON->new(file => "$source.json");

    Catmandu::Importer::JSON->new(file => $self->epmc_file)->each(sub {
        my $input = $_[0]->{resultList}->{result}->[0];
        print Dumper $input if $v;
        my $go;
        my $dbs;
        if($source eq 'citations') {
            $go = $input->{citedByCount} || 0;
        } elsif ($source eq 'references') {
            $go = (lc $input->{hasReferences} eq 'y') ? 1 : 0;
        } elsif ($source eq 'dblinks') {
            $go = (lc $input->{hasDbCrossReferences} eq 'y') ? 1 : 0;
        }
        
        if ($go) {
        my $pages = 1;

        print "Fetch $source for $input->{id}\n" if $v;

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
    }
    });
}

sub run {
    my ($self) = @_;

    $self->_fetch_initial if $self->initial;

    $self->_fetch_source($self->source) if $self->source;
}

main->new_with_options->run;

1;
