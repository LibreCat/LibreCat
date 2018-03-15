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

my $m = T::Model->new(
    bag => Catmandu->store('main')->bag('model_test'),
    search_bag => Catmandu->store('search')->bag('model_test'),
    );

ok $m->does('LibreCat::Model');
can_ok $m, $_ for qw(generate_id get _validate _add _index _purge);

my $id;
subtest 'generate_id' => sub {
    $id = $m->generate_id;
    ok $id, "generate id";

    # generate another ID
    is $id ne $m->generate_id, 1, "different IDs";
};

subtest 'get' => sub {
    my $d = $m->get(23456789543223456789);
    ok !$d, "does not exist";

    $d = $m->get($id);
    ok $d;
    is $d->{_id}, $id, "got correct ID";
};

subtest '_validate' => sub {
    $m->validate($rec);;
    ok 1;
};

subtest '_add' => sub {
    ok 1;
};

subtest '_index' => sub {
    ok 1;
};

subtest '_purge' => sub {
    ok 1;
};

done_testing;
