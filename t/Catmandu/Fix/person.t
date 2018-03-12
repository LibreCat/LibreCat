use Catmandu::Sane;
use Test::More;
use LibreCat load => (layer_paths => [qw(t/layer)]);

my $pkg;

BEGIN {
    $pkg = 'Catmandu::Fix::person';
    use_ok $pkg;
}
require_ok $pkg;

is_deeply $pkg->new()->fix(
    {
        author => [
            {first_name => 'A.', last_name => 'Einstein'},
        ]
    }
    ),
    {
    author => [
        {
            first_name => 'A.',
            last_name  => 'Einstein',
            full_name  => 'Einstein, A.'
        }
    ]
    },
    "person name handling";

done_testing;
