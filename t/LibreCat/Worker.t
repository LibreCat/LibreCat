use Test::Lib;
use TestHeader;

my $pkg;
my @worker_pkg;
BEGIN {
    $pkg = 'LibreCat::Worker';
    use_ok $pkg;
    @worker_pkg = map {
        $_ =~ s/\.pm$//;
        'LibreCat::Worker::'. $_;
        } read_dir('lib/LibreCat/Worker/');

    use_ok $_ for @worker_pkg;
}

require_ok $pkg;

require_ok $_ for @worker_pkg;

done_testing;
