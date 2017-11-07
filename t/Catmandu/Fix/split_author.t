use Catmandu::Sane;
use Test::More;

my $pkg;

BEGIN {
    $pkg = 'Catmandu::Fix::split_author';
    use_ok $pkg;
}
require_ok $pkg;

is_deeply $pkg->new()->fix(
    {
        author => [
            'Einstein, A.',
            'Einstein, Albert',
            'Albert Einstein Jr.',
            'Albert-Heinz Einstein',
        ]
    }
    ),
    {
    author => [
        {
            first_name => 'A.',
            last_name  => 'Einstein',
            full_name  => 'Einstein, A.'
        },
        {
            first_name => 'Albert',
            last_name  => 'Einstein',
            full_name  => 'Einstein, Albert'
        },
        {
            first_name => 'Albert',
            last_name  => 'Einstein Jr.',
            full_name  => 'Einstein Jr., Albert'
        },
        {
            first_name => 'Albert-Heinz',
            last_name  => 'Einstein',
            full_name  => 'Einstein, Albert-Heinz'
        },
    ]
    },
    "split authors into first/last name";

done_testing;
