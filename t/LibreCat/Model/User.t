use Catmandu::Sane;
use LibreCat load => (layer_paths => [qw(t/layer)]);
use Test::More;
use Test::Exception;
use warnings FATAL => 'all';
use Data::Dumper;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Model::User';
    use_ok $pkg;
}

require_ok $pkg;

my $user = $pkg->new(
    %{LibreCat->config->{user}},
    bag =>  Catmandu->store('main')->bag('user'),
    search_bag => Catmandu->store('search')->bag('user')
);

ok $user->does('LibreCat::Model');

ok my $u = $user->get(1234);

is $u->{_id}, '1234';

ok $u = $user->find_by_username('einstein');

is $u->{login}, 'einstein';

done_testing;
