use strict;
use warnings;
use Test::More;
use Catmandu;

use App::Catalog::Helper;

diag h->now;

my $p = {
    "deeply.nested.hash" => "Value",
    "some.0.array.key" => "Here we go!",
    "untouched" => "ok",
};

is_deeply (h->nested_params($p),
    {
        untouched => "ok",
        deeply => {nested => {hash => "Value"}},
        some => [{array => {key => "Here we go!"}}],
    },
    "nested params ok");

done_testing;
