use Catmandu::Sane;
use LibreCat -load => {layer_paths => [qw(t/layer)]};
use warnings FATAL => "all";
use Test::More;
use Test::Exception;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Worker::Audit';
    use_ok $pkg;
}

require_ok $pkg;

my $audit_bag = Catmandu->store('main')->bag('audit');
$audit_bag->delete_all;

lives_ok {$pkg->new()} "create object";

my $a = $pkg->new();
can_ok $a, "work";

my $data = {
    _id     => 1,
    action  => "update",
    bag     => "publication",
    message => "activated",
};

$a->work($data);

is $audit_bag->count, 1, "elements in audit bag";

my $saved_data = $audit_bag->first;

like $saved_data->{message}, qr/activated/,   "message field present";
like $saved_data->{bag},     qr/publication/, "bag publication";
like $saved_data->{time},    qr/\d+/,         "time field present";
ok $saved_data->{_id},       "_id field present";

# edge case: no store present
Catmandu->config->{store}->{main} = undef;

my $b = $pkg->new();
ok !$b->work($data);

END {
    # cleanup
    $audit_bag->delete_all;
}

done_testing;
