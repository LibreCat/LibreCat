#!/usr/bin/env perl

use Catmandu::Sane;
use Catmandu;
use Template;

Catmandu->load;
my $conf = Catmandu->config;

my $forms = $conf->{forms}->{publicationTypes};
my $path = $conf->{'path_to_forms'};

my $tt = Template->new(
	'START_TAG' => '{%',
	'END_TAG' => '%}',
	ENCODING => 'utf8',
	INCLUDE_PATH => '../views/backend/fields',
	OUTPUT_PATH => '../views/backend/forms',
	);

foreach my $type (keys %$forms) {

	my $type_hash = $forms->{$type};
	print "Generating $type_hash->{tmpl}.tt\n";
	$tt->process("master.tt", $type_hash, "$type_hash->{tmpl}.tt");

}