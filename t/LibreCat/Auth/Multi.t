use Catmandu::Sane;
use Test::More;
use Test::Exception;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Auth::Multi';
    use_ok $pkg;
}
require_ok $pkg;

dies_ok { $pkg->new() } 'methods required';

my @methods = [
    {
        'package' => 'LibreCat::Auth::Simple',
        options => {
            users => { demo => {password => 'demo'} },
        },
    },
    {
        'package' => 'LibreCat::Auth::LDAP',
        options => { host => "ldap.example.com" },
    },
];

lives_ok { $pkg->new(methods => @methods) } 'lives ok';

my $auth = $pkg->new(methods => @methods);

can_ok $auth, 'authenticate';

done_testing;
