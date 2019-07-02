use Catmandu::Sane;
use LibreCat -self => -load => {layer_paths => [qw(t/layer)]};
use Test::More;
use Test::Exception;

my $pkg;

BEGIN {
    $pkg = "LibreCat::Audit";
    use_ok $pkg;
}

require_ok $pkg;

my $audit;

lives_ok( sub {

    $audit = $pkg->new();

}, "object of class $pkg created" );

isa_ok $audit, $pkg;

ok $audit->does("LibreCat::Validator");
can_ok $audit, "add";
can_ok $audit, "get";
can_ok $audit, "delete";
can_ok $audit, "delete_all";
can_ok $audit, "each";
can_ok $audit, "select";

dies_ok( sub {

    $audit->is_valid(undef);

}, "$pkg is a Catmandu::Validator, so is_valid must accept hash" );

$audit->bag->delete_all();

#all attributes must be present in the record
is $audit->add({}), undef;
is scalar(@{ $audit->last_errors() // [] }), 5;

is $audit->add({ id => 1 }), undef;
is scalar(@{ $audit->last_errors() // [] }), 4;

is $audit->add({ id => 1, bag => "publication" }), undef;
is scalar(@{ $audit->last_errors() // [] }), 3;

is $audit->add({ id => 1, bag => "publication", process => "test" }), undef;
is scalar(@{ $audit->last_errors() // [] }), 2;

is $audit->add({ id => [], bag => "publication", process => "test" }), undef;
is scalar(@{ $audit->last_errors() // [] }), 3;

$audit->add({ id => 1, bag => "publication", process => "test", action => "get", message => "t" });
is scalar(@{ $audit->last_errors() // [] }), 0;

#attribute 'time' may never be present
$audit->add({ id => 1, bag => "publication", process => "test", action => "get", message => "t", time => time });
is scalar(@{ $audit->last_errors() // [] }), 1;

#acts like a Catmandu::Bag
is $audit->select( bag => "publication" )->select( id => 2 )->count, 0;
is $audit->select( bag => "publication" )->select( id => 1 )->count, 1;

END {
    # cleanup test data
    Catmandu->store('main')->bag('audit')->delete_all;
}

done_testing;
