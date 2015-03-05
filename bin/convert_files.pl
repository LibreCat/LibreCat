#!/usr/bin/env perl

use Catmandu::Sane;
use Catmandu -all;
use Catmandu::Util qw/:io/;
use File::Slurp;
use File::Path qw/make_path/;
use File::Copy;

my $base_start = '/data1/luurUnibi/uploads';
my $base_target = '/data1/pub-files/uploads';

my @dirs = read_dir($base_start);

foreach my $d (@dirs) {
    # calculate new path
    my $ext_d = sprintf("%09d", $d);
    my $p = segmented_path($ext_d, size => 3);

    # create new path
    my $new_path = join_path($base_target, $p);
    make_path($new_path,{verbose => 1});

    # copy all files from old to new path
    my $old_path = join_path($base_start,$d);
    foreach my $f (read_dir($old_path)) {
        copy( join_path($old_path,$f), $new_path ) or die "Copy failed: $!";;
        say "Copy $f";
    }
}
