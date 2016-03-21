#!/usr/bin/env perl

use lib qw(../lib /srv/www/pub/lib);

use Catmandu::Sane;
use Catmandu -all;
use Getopt::Long;
use Citation;
use Catmandu::Fix::clone as => 'clone';
use Catmandu::Importer::JSON;
use Catmandu::Exporter::JSON;
use Catmandu::Exporter::JSON;
use Data::Dumper;

Catmandu->load(':up');


my ($q, $style, $missing, $verbose, $dry, $file);

GetOptions ("q=s" => \$q,
            "style=s" => \$style,
            "missing" => \$missing,
            "verbose" => \$verbose,
            "dry" => \$dry,
	    "file=s" => \$file
            ) or die ("Error in command line arguments\n");

my $imp = Catmandu::Importer::JSON->new(file => $file);
my $exp = Catmandu::Exporter::JSON->new(file => "pub_backup_cit.json");

my $cite_obj = $style ? Citation->new(style => $style) : Citation->new(all => 1);

$imp->each(sub {
    my $rec = $_[0];
    my $d = clone $rec;
    say "processing $rec->{_id}";
    if ($missing and $rec->{citation}) {
        say "Skipping $rec->{_id}";
        next;
    }
    say "processing $rec->{_id} and $style..." if $verbose;
    $style ? ( $rec->{citation}->{$style} = $cite_obj->create($d)->{$style} )
        : ( $rec->{citation} = $cite_obj->create($d) );
    $exp->add($rec);
});

$exp->commit;

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
