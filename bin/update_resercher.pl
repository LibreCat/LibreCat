#!/usr/bin/env perl

use Catmandu::Sane;
use Catmandu -all;

Catmandu->load(':up');

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
