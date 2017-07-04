use strict;
use warnings FATAL => 'all';
use Test::More;
use Test::Exception;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Auth::SSO';
    use_ok $pkg;
}
require_ok $pkg;

Catmandu->config->{store}{users} = {
    'package' => 'Hash',
    options   => {init_data => {login => 'demo', password => 's3cret',},},
};

lives_ok { $pkg->new() } 'lives ok';

my $auth = LibreCat::Auth::Bag->new(store => 'users', username_attr => 'login',);

can_ok $auth, 'authenticate';

done_testing;
