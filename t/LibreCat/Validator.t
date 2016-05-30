use Test::Lib;
use TestHeader;

my @worker_pkg;

BEGIN {
    @worker_pkg = map {
        $_ =~ s/\.pm$//;
        'LibreCat::Validator::' . $_;
    } read_dir('lib/LibreCat/Validator/');

    use_ok $_ for @worker_pkg;
}

require_ok $_ for @worker_pkg;

#isa_ok $_, "Catmandu::Validator" for @worker_pkg;

done_testing;
