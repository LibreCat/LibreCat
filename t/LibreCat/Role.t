BEGIN {
    use Catmandu::Sane;
    use Path::Tiny;
    use LibreCat::Layers;
    LibreCat::Layers->new(layer_paths => [qw(t/layer)])->load;
}

use Catmandu::Sane;
use Test::More;
use Test::Exception;
use Catmandu::Util qw(is_string is_code_ref);
use LibreCat;
use LibreCat::Role;

my $rule_config = Catmandu->config->{user}{rules};
my $role;
my $user = LibreCat->user->get_by_username('user1');

lives_ok {$role = LibreCat::Role->new(rule_config => $rule_config)};
is_deeply $role->rules, [];
ok is_string($role->match_code);
lives_ok {$role->matcher};
ok is_code_ref($role->matcher);

is $role->may($user, 'eat'), 0;

$role = LibreCat::Role->new(
    rule_config => $rule_config,
    rules       => [[qw(can eat)],]
);

is $role->may($user, 'eat'), 1;
is $role->may($user, 'eat', {_type => 'cookie'}), 1;

$role = LibreCat::Role->new(
    rule_config => $rule_config,
    rules       => [[qw(can eat carrot)],]
);

is $role->may($user, 'eat'), 0;
is $role->may($user, 'eat', {_type => 'cookie'}), 0;
is $role->may($user, 'eat', {_type => 'carrot'}), 1;

$role = LibreCat::Role->new(
    rule_config => $rule_config,
    rules       => [[qw(can eat food)], [qw(cannot eat food/cookie)],]
);

is $role->may($user, 'eat'), 0;
is $role->may($user, 'eat', {_type => 'shoe'}),        0;
is $role->may($user, 'eat', {_type => 'food'}),        1;
is $role->may($user, 'eat', {_type => 'food/cookie'}), 0;
is $role->may($user, 'eat', {_type => 'food/carrot'}), 1;

$role = LibreCat::Role->new(
    rule_config => $rule_config,
    rules       => [
        [qw(can eat food)], [qw(cannot eat food/cookie)],
        [qw(can eat food/cookie healthy)],
    ]
);

is $role->may($user, 'eat', {_type => 'food'}),        1;
is $role->may($user, 'eat', {_type => 'food/cookie'}), 0;
is $role->may($user, 'eat', {_type => 'food/carrot', healthy => 0}), 1;
is $role->may($user, 'eat', {_type => 'food/cookie', healthy => 1}), 1;

$role = LibreCat::Role->new(
    rule_config => $rule_config,
    rules       => [
        [qw(can eat fruit)], [qw(can eat vegetable)],
        [qw(cannot eat fruit color red)],
    ]
);

is $role->may($user, 'eat', {_type => 'fruit/apple'}), 1;
is $role->may($user, 'eat', {_type => 'fruit/apple', color => 'yellow'}), 1;
is $role->may($user, 'eat', {_type => 'fruit/apple', color => 'red'}),    0;
is $role->may($user, 'eat', {_type => 'vegetable/tomato', color => 'red'}), 1;

$role = LibreCat::Role->new(
    rule_config => $rule_config,
    rules       => [[qw(can edit publication own)],]
);

is $role->may($user, 'edit', {_type => 'publication'}), 0;
is $role->may($user, 'edit',
    {_type => 'publication', creator => {login => 'user2'}}),
    0;
is $role->may($user, 'edit',
    {_type => 'publication', creator => {login => 'user1'}}),
    1;
is $role->may($user, 'edit',
    {_type => 'project', creator => {login => 'user1'}}),
    0;

$role = LibreCat::Role->new(
    rule_config => $rule_config,
    rules       => [[qw(can edit publication owned_by user2)],]
);

is $role->may($user, 'edit', {_type => 'publication'}), 0;
is $role->may($user, 'edit',
    {_type => 'publication', creator => {login => 'user1'}}),
    0;
is $role->may($user, 'edit',
    {_type => 'publication', creator => {login => 'user2'}}),
    1;

$role = LibreCat::Role->new(
    rule_config => $rule_config,
    rules       => [
        [qw(can edit publication affiliated_with dep1)],
        [qw(can edit publication affiliated_with fac2)],
    ]
);

is $role->may($user, 'edit', {_type => 'publication'}), 0;
is $role->may($user, 'edit',
    {_type => 'publication', department => {_id => 'dep2'}}),
    0;
is $role->may($user, 'edit',
    {_type => 'publication', department => {_id => 'dep1'}}),
    1;
is $role->may(
    $user, 'edit',
    {
        _type      => 'publication',
        department => {_id => 'dep2', tree => [{_id => 'fac2'}]}
    }
    ),
    1;

# wildcards
$role = LibreCat::Role->new(
    rule_config => $rule_config,
    rules       => [
        [qw(can drink *)],
    ]
);

is $role->may($user, 'drink', {_type => 'slurm'}), 1;
is $role->may($user, 'drink', {}), 1;
is $role->may($user, 'drink', undef), 0;
is $role->may($user, 'eat', {}), 0;

$role = LibreCat::Role->new(
    rule_config => $rule_config,
    rules       => [
        [qw(can * *)],
    ]
);

is $role->may($user, 'drink', {}), 1;
is $role->may($user, 'drink', undef), 0;
is $role->may($user, 'eat', {}), 1;

$role = LibreCat::Role->new(
    rule_config => $rule_config,
    rules       => [
        [qw(can *)],
    ]
);

is $role->may($user, 'drink', {}), 1;
is $role->may($user, 'drink', undef), 1;
is $role->may($user, 'eat', {}), 1;

done_testing;

1;

