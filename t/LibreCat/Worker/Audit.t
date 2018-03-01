use Catmandu::Sane;
use Test::More;
use Test::Exception;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Worker::Audit';
    use_ok $pkg;
}

require_ok $pkg;

done_testing;
