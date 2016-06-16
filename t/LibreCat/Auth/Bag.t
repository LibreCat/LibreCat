use Test::Lib;
use TestHeader;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Auth::Bag';
    use_ok $pkg;
}
require_ok $pkg;

Catmandu->config->{store}{users} = {
    'package' => 'Hash',
    options   => {init_data => {login => 'demo', password => 's3cret',},},
};

lives_ok {$pkg->new()} 'lives ok';

my $auth
    = LibreCat::Auth::Bag->new(store => 'users', username_attr => 'login',);

can_ok $auth, 'authenticate';

#my $check = $auth->authenticate({
#        username => 'demo',
#        password => 's3cret',

done_testing;
