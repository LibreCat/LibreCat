use strict;
use warnings FATAL => 'all';
use Test::More;
use File::Slurp;

my $pkg;
my @fs_pkg;

BEGIN {
    $pkg = 'LibreCat::FileStore';
    use_ok $pkg;
    @fs_pkg = map {
        $_ =~ s/\.pm$//;
        'LibreCat::FileStore::' . $_;
    } read_dir('lib/LibreCat/FileStore/');

    use_ok $_ for @fs_pkg;
}

require_ok $pkg;

require_ok $_ for @fs_pkg;

done_testing;
