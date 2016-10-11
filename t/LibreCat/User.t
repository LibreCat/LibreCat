BEGIN {
    use Catmandu::Sane;
    use Path::Tiny;
    use LibreCat::Layers;
    LibreCat::Layers->new(layer_paths => [qw(t/layer)])->load;
}

use Catmandu::Sane;
use Test::More;
use Test::Exception;
use Catmandu;
use LibreCat::User;

my $users;
my $user1 = Catmandu->store('builtin_users_1')->bag->get('1');
my $user2 = Catmandu->store('builtin_users_2')->bag->get('2');

lives_ok {$users=LibreCat::User->new};
lives_ok {$users=LibreCat::User->new(Catmandu->config->{user})};

my $user;

$user = $users->find_by_username('user1');
is_deeply $user, $user1;
$user = $users->find_by_username('user2');
is_deeply $user, $user2;

$user = $users->get(1);
is_deeply $user, $user1;
$user = $users->get(2);
is_deeply $user, $user2;

$user = $users->find_by_username('user1');
is $users->may($user, 'view', {_type => 'publication'}), 0;
is $users->may($user, 'view', {_type => 'publication', status => 'public'}), 1;
is $users->may($user, 'view', {_type => 'publication', creator => {login => 'user2'}}), 0;
is $users->may($user, 'view', {_type => 'publication', creator => {login => 'user1'}}), 1;

$user = $users->find_by_username('user3');
# reviewer is also a user
is $users->may($user, 'edit', {_type => 'publication', creator => {login => 'user3'}}), 1;
# parametric role {department => 'dep1'}
is $users->may($user, 'edit', {_type => 'publication', department => {_id => 'dep2'}}), 0;
is $users->may($user, 'edit', {_type => 'publication', department => {_id => 'dep1'}}), 1;

done_testing;
