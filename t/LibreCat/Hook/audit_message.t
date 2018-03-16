use Catmandu::Sane;
use warnings FATAL => 'all';
use Test::More;
use Test::Exception;
use LibreCat load => (layer_paths => [qw(t/layer)]);

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Hook::audit_message';
    use_ok $pkg;
}
require_ok $pkg;

my $x;
lives_ok { $x = $pkg->new() } 'lives_ok';


ok my $y = $pkg->new(name => 'publication_update');

can_ok $x, 'fix';

my $data = [
    {},
    {
        _id => 1
    },
    {
        user_id => 1234,
    },
    {
        _id => 2,
        user_id => 1234,
    },
    {
        _id => 2,
        user_id => 23456789009876,
    },
];

ok $x->fix($_) for @$data;
ok $y->fix($_) for @$data;

done_testing;
