use Catmandu::Sane;
use LibreCat load => (layer_paths => [qw(t/layer)]);
use Test::More;
use Test::Exception;
use Role::Tiny;

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

    package T::Validator;
    use Moo;

    with 'LibreCat::Validator';

    sub validate_data { }
}

my $m = T::Model->new(
    bag        => Catmandu->store('main')->bag('model_test'),
    search_bag => Catmandu->store('search')->bag('model_test'),
    validator  => T::Validator->new,
);

ok $m->does('LibreCat::Model');
can_ok $m, $_ for qw(generate_id get add delete is_valid);

my $id;
subtest 'generate_id' => sub {
    $id = $m->generate_id;
    ok $id, "generate id";

    # generate another id
    ok $id ne $m->generate_id, "different IDs";
};

subtest 'get' => sub {
    my $d = $m->get(23456789543223456789);
    ok !$d, "does not exist";

    #$d = $m->get($id);
    #ok !!$d;
    #is $d->{_id}, $id, "got correct id";
};

done_testing;
