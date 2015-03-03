#!/usr/bin/env perl

use FindBin qw($Bin);
use Catmandu::Sane;
use Catmandu;
use Template;

Catmandu->load(':up');
my $conf = Catmandu->config;

my $forms = $conf->{forms}->{publicationTypes};

#my $path = $conf->{'path_to_forms'};

my $tt = Template->new(
    START_TAG  => '{%',
    END_TAG    => '%}',
    ENCODING     => 'utf8',
    INCLUDE_PATH => "$Bin/../views/backend",
    OUTPUT_PATH  => "$Bin/../views/backend/forms",
);

foreach my $type ( keys %$forms ) {

    my $type_hash = $forms->{$type};
    $type_hash->{field_order} = $conf->{forms}->{field_order};
    if($type_hash->{tmpl} and $type_hash->{fields}){
    	print "Generating $type_hash->{tmpl}.tt\n";
    	$tt->process( "master.tt", $type_hash, "$type_hash->{tmpl}.tt" ) || die $tt->error(), "\n";
    	print "Generating expert/$type_hash->{tmpl}.tt\n";
    	$tt->process( "master_expert.tt", $type_hash, "expert/$type_hash->{tmpl}.tt" ) || die $tt->error(), "\n";
    }

}
