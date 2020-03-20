use Catmandu::Sane;
use LibreCat -self => -load => {layer_paths => [qw(t/layer)]};
use Test::More;
use Test::Exception;

my $pkg;

BEGIN {
    $pkg = "LibreCat::Message";
    use_ok $pkg;
}

require_ok $pkg;

my $msg;

lives_ok(
    sub {

        $msg = $pkg->new();

    },
    "object of class $pkg created"
);

isa_ok $msg, $pkg;

ok $msg->does("LibreCat::Validator");
can_ok $msg, "add";
can_ok $msg, "get";
can_ok $msg, "delete";
can_ok $msg, "delete_all";
can_ok $msg, "each";
can_ok $msg, "select";

dies_ok(
    sub {

        $msg->is_valid(undef);

    },
    "$pkg is a Catmandu::Validator, so is_valid must accept hash"
);

$msg->bag->delete_all();

# all attributes must be present in the record
is $msg->add({}), undef;
is scalar(@{$msg->last_errors() // []}), 3;

is $msg->add({record_id => 1}), undef;
is scalar(@{$msg->last_errors() // []}), 2;

is $msg->add({record_id => 1, message => "added publication"}), undef;
is scalar(@{$msg->last_errors() // []}), 1;

$msg->add({record_id => 1, user_id => 1234, message => "added publication"});
is scalar(@{$msg->last_errors() // []}), 0;

# attribute 'time' may never be present
$msg->add(
    {
        record_id => 1,
        user_id   => 1234,
        message   => "added publication",
        time      => time
    }
);
is scalar(@{$msg->last_errors() // []}), 1;

# acts like a Catmandu::Bag
is $msg->select(record_id => 1)->count, 1;

END {
    # cleanup test data
    Catmandu->store('main')->bag('message')->delete_all;
}

done_testing;
