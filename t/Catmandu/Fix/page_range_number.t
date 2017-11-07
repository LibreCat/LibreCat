use Catmandu::Sane;
use Test::More;

my $pkg;

BEGIN {
    $pkg = 'Catmandu::Fix::page_range_number';
    use_ok $pkg;
}
require_ok $pkg;

is_deeply $pkg->new()
    ->fix({page_range_number => {type => 'whatever', value => '123',}}),
    {page => '123'}, "unknown type: is page";

is_deeply $pkg->new()
    ->fix(
    {page_range_number => {type => 'article_number', value => 'e23414',}}),
    {article_number => 'e23414'}, "is article number";

done_testing;
