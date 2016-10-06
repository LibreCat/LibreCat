use strict;
use warnings FATAL => 'all';
use Test::More;
use File::Slurp;

my $pkg;
my @worker_pkg;

BEGIN {
    $pkg = 'LibreCat::FileStore';
    use_ok $pkg;
    @worker_pkg = map {
        $_ =~ s/\.pm$//;
        'LibreCat::Worker::' . $_;
    } read_dir('lib/LibreCat/Worker/');

    use_ok $_ for @worker_pkg;
}

require_ok $pkg;

require_ok $_ for @worker_pkg;

done_testing;
