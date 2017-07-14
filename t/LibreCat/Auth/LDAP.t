use Catmandu::Sane;
use Test::More;
use Test::Exception;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Auth::LDAP';
    use_ok $pkg;
}
require_ok $pkg;

dies_ok {$pkg->new()} 'host and auth_base required';
dies_ok {$pkg->new(host => 'ldap.example.com')} 'auth_base required';
dies_ok {$pkg->new(auth_base => 'ID=%s,ou=people')} 'host required';

lives_ok {
    $pkg->new(host => 'ldap.example.com', auth_base => 'ID=%s,ou=people')
}
'lives ok';

my $auth
    = $pkg->new(host => 'ldap.example.com', auth_base => 'ID=%s,ou=people');

can_ok $auth, $_ for qw(authenticate search);

done_testing;
