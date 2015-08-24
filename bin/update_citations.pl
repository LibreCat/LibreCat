#!/usr/bin/env perl

use lib qw(/srv/www/pub/lib);

use Catmandu::Sane;
use Catmandu -all;
use Getopt::Long;
use Citation;
#use App::Catalogue::Controller::Publication qw/update_publication/;
use POSIX qw(strftime);
use Data::Dumper;

Catmandu->load(':up');
#Catmandu->config;

my ($id, $style, $missing, $verbose);

GetOptions ("id=i" => \$id,
            "style=s"   => \$style,
            "missing"  => \$missing,
            "verbose" => \$verbose)
or die("Error in command line arguments\n");

#my $bag = Catmandu->store('search')->bag('publication');
use Catmandu::Importer::JSON;
use Catmandu::Exporter::JSON;

my $bag = Catmandu::Importer::JSON->new(file => "pub_backup.json");
#my $backup = Catmandu->store('backup')->bag('publication');
my $backup = Catmandu::Exporter::JSON->new(file => "pub_backup_cit.json");

print Dumper strftime("%Y-%m-%dT%H:%M:%SZ", gmtime(time));

$bag->each(sub {
    my $rec = $_[0];
#    my $citation = Citation::index_citation_update($rec,0,'','default');
#    $rec->{citation}->{'default'} = $citation->{'default'};
#    my $result = $backup->add($rec);
    if ($missing && (!$rec->{citation} or !$rec->{citation}->{'default'})) {
    		print "Adding citation for $rec->{_id}\n" if $verbose;
    		$rec->{citation} = Citation::index_citation_update($rec,0,'');
    		#print Dumper $rec->{citation};

        my $result = $backup->add($rec);
        #$bag->add($result);
        #$bag->commit;
    }
});

print "Done\n";
print Dumper strftime("%Y-%m-%dT%H:%M:%SZ", gmtime(time));
