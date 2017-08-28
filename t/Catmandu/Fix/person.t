use Catmandu::Sane;
use Test::More;

my $pkg;

BEGIN {
    $pkg = 'Catmandu::Fix::person';
    use_ok $pkg;
}
require_ok $pkg;

is_deeply $pkg->new()->fix(
    {
        author => [
            {first_name => 'DeleteMe'},
            {last_name => 'DeleteMeEither'},
            {first_name => 'A.', last_name => 'Einstein'},
            {},
        ]
    }
    ),
    {
        author => [
            {first_name => 'A.', last_name => 'Einstein', full_name => 'Einstein, A.'}
        ]
    },
    "person name handling";

done_testing;
