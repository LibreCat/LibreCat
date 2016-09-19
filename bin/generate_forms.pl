#!/usr/bin/env perl

my $layers;

BEGIN {
    use Catmandu::Sane;
    use Path::Tiny;
    use lib path(__FILE__)->parent->parent->child('lib')->stringify;
    use LibreCat::Layers;

    $layers = LibreCat::Layers->new->load;
};

use Catmandu::Sane;
use Catmandu;
use Template;

my $conf            = Catmandu->config;
my $forms           = $conf->{forms}{publication_types};
my $other_items     = $conf->{forms}{other_items};
my $template_paths  = $layers->template_paths;
my $output_path     = $template_paths->[0] . '/backend/forms';

#-----------------

print "[$output_path]\n";
my $tt = Template->new(
    START_TAG  => '{%',
    END_TAG    => '%}',
    ENCODING     => 'utf8',
    INCLUDE_PATH => [ map { "$_/backend/generator" } @$template_paths ],
    OUTPUT_PATH  => $output_path,
);

foreach my $type ( keys %$forms ) {
    my $type_hash = $forms->{$type};
    $type_hash->{field_order} = $conf->{forms}{field_order};
    if($type_hash->{fields}){
        print "Generating $output_path/$type.tt\n";
        $tt->process( "master.tt", $type_hash, "$type.tt" ) || die $tt->error(), "\n";
        print "Generating $output_path/expert/$type.tt\n";
        $tt->process( "master_expert.tt", $type_hash, "expert/$type.tt" ) || die $tt->error(), "\n";
    }
}

#-----------------

$output_path = $template_paths->[0] . '/admin/forms';

print "[$output_path]\n";

my $tta = Template->new(
    START_TAG  => '{%',
    END_TAG    => '%}',
    ENCODING     => 'utf8',
    INCLUDE_PATH => [ map { "$_/admin/generator" } @$template_paths ],
    OUTPUT_PATH  => $output_path,
);

foreach my $item (keys %$other_items) {
    print "Generating $output_path/edit_$item page\n";
    $tta->process( "master_$item.tt", $other_items->{$item}, "edit_$item.tt" ) || die $tta->error(), "\n";
}
