use Catmandu::Sane;
use LibreCat load => (layer_paths => [qw(t/layer)]);
use Test::More;
use Test::Exception;
use Role::Tiny;
use warnings FATAL => 'all';

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Model';
    use_ok $pkg;
}

require_ok $pkg;

{

    package T::Model;
    use Moo;

    with $pkg;
}

my $m = T::Model->new(bag => xxx, search_bag => yyy,);

ok $m->does('LibreCat::Model');
can_ok $m, $_ for qw(generate_id get _add _index _purge _validate);

done_testing;
