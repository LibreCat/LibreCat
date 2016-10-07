use Catmandu::Sane;
use Test::More;
use Test::Exception;
use Catmandu::Util qw(is_string is_code_ref);
use LibreCat::Role;

my $role;
my $user = {};

lives_ok {$role = LibreCat::Role->new};
is_deeply $role->rules, [];
ok is_string($role->match_code);
lives_ok {$role->matcher};
ok is_code_ref($role->matcher);

is $role->may($user, 'eat'), 0;

$role = LibreCat::Role->new(rules => [[qw(can eat)],]);

is $role->may($user, 'eat'), 1;
is $role->may($user, 'eat', {_type => 'cookie'}), 1;

$role = LibreCat::Role->new(rules => [[qw(can eat carrot)],]);

is $role->may($user, 'eat'), 0;
is $role->may($user, 'eat', {_type => 'cookie'}), 0;
is $role->may($user, 'eat', {_type => 'carrot'}), 1;

$role = LibreCat::Role->new(
    rules => [[qw(can eat food)], [qw(cannot eat food/cookie)],]);

is $role->may($user, 'eat'), 0;
is $role->may($user, 'eat', {_type => 'shoe'}),        0;
is $role->may($user, 'eat', {_type => 'food'}),        1;
is $role->may($user, 'eat', {_type => 'food/cookie'}), 0;
is $role->may($user, 'eat', {_type => 'food/carrot'}), 1;

$role = LibreCat::Role->new(
    rules => [
        [qw(can eat food)], [qw(cannot eat food/cookie)],
        [qw(can eat food/cookie healthy)],
    ]
);

is $role->may($user, 'eat', {_type => 'food'}),        1;
is $role->may($user, 'eat', {_type => 'food/cookie'}), 0;
is $role->may($user, 'eat', {_type => 'food/carrot', healthy => 0}), 1;
is $role->may($user, 'eat', {_type => 'food/cookie', healthy => 1}), 1;

$role = LibreCat::Role->new(
    rules => [
        [qw(can eat fruit)], [qw(can eat vegetable)],
        [qw(cannot eat fruit color red)],
    ]
);

is $role->may($user, 'eat', {_type => 'fruit/apple'}), 1;
is $role->may($user, 'eat', {_type => 'fruit/apple', color => 'yellow'}), 1;
is $role->may($user, 'eat', {_type => 'fruit/apple', color => 'red'}),    0;
is $role->may($user, 'eat', {_type => 'vegetable/tomato', color => 'red'}), 1;

done_testing;

1;

