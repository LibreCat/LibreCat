use strict;
use warnings FATAL => "all";
use Catmandu;
use Test::More;

my $pkg;

BEGIN {
    $pkg = 'Catmandu::Bag::IdGenerator::Incremental';
    use_ok $pkg;
}
require_ok $pkg;

Catmandu->config->{store} = {
    id_test => {
        "package" => "Hash",
        options => {
            bags => {
                data => {id_generator => "Incremental"}
            }
        }
    }
};

{
    my $expected     = [1 .. 10];
    my $generated    = [];
    my $bag = Catmandu->store('id_test')->bag('data');

    push @$generated, map {$bag->generate_id} @$expected;
    is_deeply $generated, $expected,
        "generated ids correct";
}

done_testing;
