use Catmandu::Sane;
use Test::More;
use Test::Exception;
use Catmandu::Util qw(is_string is_code_ref);
use LibreCat::Role;

my $role;
my $user = {};

lives_ok { $role = LibreCat::Role->new };
is_deeply $role->rules, [];
ok is_string($role->match_code);
lives_ok { $role->matcher };
ok is_code_ref($role->matcher);

is $role->may($user, 'eat'), 0;

$role = LibreCat::Role->new(rules => [
    [qw(can eat)],
]);

is $role->may($user, 'eat'), 1;
is $role->may($user, 'eat', {_type => 'cookie'}), 1;

$role = LibreCat::Role->new(rules => [
    [qw(can eat carrot)],
]);

is $role->may($user, 'eat'), 0;
is $role->may($user, 'eat', {_type => 'cookie'}), 0;
is $role->may($user, 'eat', {_type => 'carrot'}), 1;

$role = LibreCat::Role->new(rules => [
    [qw(can eat food)],
    [qw(cannot eat food/cookie)],
]);

is $role->may($user, 'eat'), 0;
is $role->may($user, 'eat', {_type => 'food'}), 1;
is $role->may($user, 'eat', {_type => 'food/cookie'}), 0;
is $role->may($user, 'eat', {_type => 'food/carrot'}), 1;

done_testing;

1;

