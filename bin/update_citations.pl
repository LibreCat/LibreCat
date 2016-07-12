#!/usr/bin/env perl

use lib qw(../lib /srv/www/pub/lib ../fixes /srv/www/pub/fixes);

use Catmandu::Sane;
use Catmandu -all;
#use Getopt::Long;
use LibreCat::Citation;
use Catmandu::Fix::clone as => 'clone';
use Catmandu::Importer::JSON;
#use Catmandu::Exporter::JSON;
use App::Helper;
use Data::Dumper;

Catmandu->load('/srv/www/pub');


#my ($q, $style, $missing, $verbose, $dry, $file);

#GetOptions ("q=s" => \$q,
#            "style=s" => \$style,
#            "missing" => \$missing,
#            "verbose" => \$verbose,
#            "dry" => \$dry,
#	    "file=s" => \$file
#            ) or die ("Error in command line arguments\n");

my $imp = Catmandu::Importer::JSON->new(file => 'publs2.json');#$file);
#my $exp = Catmandu::Exporter::JSON->new(file => "pub_backup_cit.json");

#my $cite_obj = $style ? Citation->new(style => $style) : Citation->new(all => 1);

$imp->each(sub {
    my $id = $_[0]->{_id};
    my $rec = h->backup_publication->get($id);
    next if $rec->{status} eq "deleted";
    #my $d = clone $rec;
    #$rec->{citation} = LibreCat::Citation->new(all => 1)->create($d);
    my $fixer = Catmandu::Fix->new(fixes => ["add_citation()"]);
    $fixer->fix($rec);
    #print Dumper $rec;
    my $saved = h->backup_publication_static->add($rec);

    #h->publication->add($saved);
    #h->publication->commit;
});

#$exp->commit;

#if (!$dry) {
#    my $saved = $backup->add_many($hits);
#    $bag->add_many($saved);

#    $backup->commit;
#    $bag->commit;
#} else {
#    $exp->add_many($hits);
#}

__END__
=head1 NAME

update_citations.pl

=head2 USAGE

perl bin/update_citations.pl [options]

=head2 OPTIONS

=over

=item --dry:

Dry run.

=item --style:

Specify the style. If no style is provided all styles will be processed.

=item --q:

Specify the CQL query. If no query is given all records will be processed.

=item --missing:

This flag flag will only affect records with no citations.

=item --verbose:

Prints some messages to STDOUT.

=back

=cut
