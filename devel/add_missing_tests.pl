#!/usr/bin/env perl
#
# Create basic tests for .pm files in lib
#

use Path::Tiny;
use Getopt::Long;

my $do_real;

GetOptions("x" => \$do_real);

my $iter = path("lib")->iterator({ recurse => 1});

while ( $path = $iter->() ) {
    next unless -f $path && $path =~ m{\.pm$};

    my $test_file = $path;
    $test_file =~ s{^lib}{t};
    $test_file =~ s{\.pm}{.t};

    next if -f $test_file;

    my $test_directory = $test_file;
    $test_directory =~ s{\/[^\/]+$}{\/};

    my $package_name = $test_file;
    $package_name =~ s{t/}{};
    $package_name =~ s{\.t$}{};
    $package_name =~ s{\/}{::}g;

    my $test_code =<<EOF;
use Catmandu::Sane;
use LibreCat load => (layer_paths => [qw(t/layer)]);
use Test::More;
use Test::Exception;
use warnings FATAL => 'all';

my \$pkg;

BEGIN {
    \$pkg = '$package_name';
    use_ok \$pkg;
};

require_ok \$pkg;

done_testing;
EOF

    print "$package_name $test_file... ";

    if ($do_real) {
        path($test_directory)->mkpath();
        path($test_file)->spew_utf8($test_code);
        print "ok\n";
    }
    else {
        print "demo - use -x for real processing\n";
    }
}
