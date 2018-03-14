use Catmandu::Sane;
use Test::More;
use Test::Exception;
use Test::Net::LDAP::Util qw(ldap_mockify);

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Auth::LDAP';
    use_ok $pkg;
}
require_ok $pkg;

dies_ok {$pkg->new()} 'host and auth_base required';
dies_ok {$pkg->new(host => 'localhost')} 'auth_base required';
dies_ok {$pkg->new(auth_base => 'ID=%s,ou=people')} 'host required';

lives_ok {
    $pkg->new(host => 'ldap.example.com', auth_base => 'ID=%s,ou=people')
}
'lives ok';

{
    my $auth = $pkg->new(host => 'localhost', auth_base => 'ID=%s,ou=people');

    can_ok $auth, $_ for qw(authenticate search);

    ok !$auth->ldap, "can't connect to a local ldap host";
}

ldap_mockify {
    my $ldap = Net::LDAP->new('ldap.example.com');
    $ldap->add('uid=felix, ou=people, dc=example, dc=com', attrs => [
        'personID' => '2381938120381'
    ]);
    my $auth = $pkg->new(
                host          => 'localhost',
                auth_base     => 'ID=%s,ou=people',
                search_filter => '(uid=%s)',
                search_base   => 'dc=example, dc=com',
                search_attr   => 'personID',
                ldap          => $ldap);

    ok $auth, "created a ldap connection";
    isa_ok $auth->ldap , 'Test::Net::LDAP';

    ok ! $auth->_authenticate();
    ok ! $auth->_authenticate({});
    
    my $res =  $auth->_authenticate({ username => "felix", password => "test" });

    is_deeply $res , {
        package    => 'LibreCat::Auth::LDAP' ,
        uid        => '2381938120381' ,
        package_id => 'LibreCat::Auth::LDAP'
    } , "got an authenticated user";

    dies_ok { $pkg->new(
                host          => 'localhost',
                auth_base     => 'ID=%s,ou=people',
                ldap          => $ldap)->search('felix')
            } , 'need search_filter';

    dies_ok { $pkg->new(
                host          => 'localhost',
                auth_base     => 'ID=%s,ou=people',
                search_filter => '(uid=%s)',
                ldap          => $ldap)->search('felix')
            } , 'need search_base';

    dies_ok { $pkg->new(
                host          => 'localhost',
                auth_base     => 'ID=%s,ou=people',
                search_filter => '(uid=%s)',
                search_base   => 'dc=example, dc=com',
                ldap          => $ldap)->search('felix')
            } , 'need search_attr';

    ok ! $pkg->new(
                host          => 'localhost',
                auth_base     => 'ID=%s,ou=test',
                search_filter => '(uid=%s)',
                search_base   => 'dc=test',
                search_attr   => 'personID',
                ldap          => $ldap)->search('felix'), "can't find felix";
};

done_testing;
