use strict;
use warnings FATAL => 'all';
use Test::More;
use Test::Exception;
use LibreCat -load => {layer_paths => [qw(t/layer)]};

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Error';
    use_ok $pkg;
}

require_ok $pkg;

lives_ok { LibreCat::Error->new } 'create error instances';

throws_ok { LibreCat::Error->throw } $pkg, 'throw errors';

done_testing;
