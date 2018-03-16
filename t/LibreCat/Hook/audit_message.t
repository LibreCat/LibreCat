use Catmandu::Sane;
use warnings FATAL => 'all';
use Test::More;
use Test::Exception;
use LibreCat load => (layer_paths => [qw(t/layer)]);
use Data::Dumper;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Hook::audit_message';
    use_ok $pkg;
}
require_ok $pkg;

# empty audit db
my $audit = Catmandu->store('main')->bag('audit');
$audit->delete_all;

lives_ok { $pkg->new } 'lives_ok';

ok $pkg->new->fix({}), "can call pkg without args";

ok my $x = $pkg->new(name => 'publication_update'), "can call pkg with args";

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

ok $x->fix($_), "apply hook" for @$data;

my $audit_data = $audit->to_array;

is @$audit_data, 5, "5 elements in audit bag";

my $a = $audit_data->[0];

like $a->{message}, qr/activated/, "message field present";
like $a->{bag}, qr/publication/, "bag publication";
like $a->{time}, qr/\d+/, "time field present";
ok $a->{_id}, "_id field present";

END {
    # cleanup
    Catmandu->store('main')->bag('audit')->delete_all;
}

done_testing;
