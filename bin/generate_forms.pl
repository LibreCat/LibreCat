#!/usr/bin/env perl

my $layers;

BEGIN {
    use Catmandu::Sane;
    use Path::Tiny;
    use lib path(__FILE__)->parent->parent->child('lib')->stringify;
    use LibreCat::Layers;

    LibreCat::Layers->new->load;
};

use Catmandu::Sane;
use Catmandu;
use Template;

my $conf = Catmandu->config;

my $forms = $conf->{forms}->{publication_types};
my $other_items = $conf->{forms}->{other_items};

my $tt = Template->new(
    START_TAG  => '{%',
    END_TAG    => '%}',
    ENCODING     => 'utf8',
    INCLUDE_PATH => Catmandu->root.'/views/backend/generator',
    OUTPUT_PATH  => Catmandu->root.'/views/backend/forms',
);

foreach my $type ( keys %$forms ) {

    my $type_hash = $forms->{$type};
    $type_hash->{field_order} = $conf->{forms}->{field_order};
    if($type_hash->{fields}){
        print "Generating $type.tt\n";
        $tt->process( "master.tt", $type_hash, "$type.tt" ) || die $tt->error(), "\n";
        print "Generating expert/$type.tt\n";
        $tt->process( "master_expert.tt", $type_hash, "expert/$type.tt" ) || die $tt->error(), "\n";
    }

}

my $tta = Template->new(
    START_TAG  => '{%',
    END_TAG    => '%}',
    ENCODING     => 'utf8',
    INCLUDE_PATH => Catmandu->root.'/views/admin/generator',
    OUTPUT_PATH  => Catmandu->root.'/views/admin/forms',
);

foreach my $item (keys %$other_items) {

    print "Generating edit_$item page\n";
    $tta->process( "master_$item.tt", $other_items->{$item}, "edit_$item.tt" ) || die $tta->error(), "\n";

}
