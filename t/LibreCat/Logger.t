use Catmandu::Sane;
use LibreCat load => (layer_paths => [qw(t/layer)]);
use Test::More;
use Test::Exception;
use Role::Tiny;
use warnings FATAL => 'all';

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Logger';
    use_ok $pkg;
}

require_ok $pkg;

{

    package T::Logger;
    use Moo;

    with $pkg;
}

my $l = T::Logger->new();

ok $l->does('LibreCat::Logger');
can_ok $l, 'log';

done_testing;
