use Catmandu::Sane;
use Test::More;

my $pkg;

BEGIN {
    $pkg = 'Catmandu::Fix::volume_sort';
    use_ok $pkg;
}
require_ok $pkg;

is_deeply $pkg->new()->fix({volume => '2342A',}), {volume => '2342A',},
    "no intvolume";

is_deeply $pkg->new()->fix({volume => 2342,}),
    {volume => 2342, intvolume => '      2342',}, "prepend whitespaces";

done_testing;
