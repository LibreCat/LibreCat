use strict;
use warnings FATAL => 'all';
use Test::More;
use Test::Exception;
use LibreCat -load => {layer_paths => [qw(t/layer)]};

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Error::VersionConflict';
    use_ok $pkg;
}

require_ok $pkg;

done_testing;
