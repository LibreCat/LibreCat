#!/usr/bin/env perl

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
    INCLUDE_PATH => '/srv/www/app-catalog/views/backend',
    OUTPUT_PATH  => '/srv/www/app-catalog/views/backend/forms',
);

foreach my $type ( keys %$forms ) {

    my $type_hash = $forms->{$type};
    $type_hash->{field_order} = $conf->{forms}->{field_order};
    print "Generating $type_hash->{tmpl}.tt\n";
    $tt->process( "master.tt", $type_hash, "$type_hash->{tmpl}.tt" ) || die $tt->error(), "\n";

}
