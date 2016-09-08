#!/usr/bin/env perl

BEGIN {
    use Catmandu::Sane;
    use Path::Tiny;
    use lib path(__FILE__)->parent->parent->child('lib')->stringify;
    use LibreCat::Layers;

    LibreCat::Layers->new->load;
};

use Catmandu::Sane;
use Catmandu;

my $backup = Catmandu->store('backup')->bag('researcher');
my $fixer = Catmandu::Fix->new(fixes => ["add_num_of_publs()"]);

$backup->each(sub {
    my $rec = $_[0];
    $fixer->fix($rec);
    my $saved = $backup->add($rec);
    print "Processing $rec->{full_name}...\n";
});

$backup->commit;
print "Done!\n";
