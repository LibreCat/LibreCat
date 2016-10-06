use Catmandu::Sane;
use Test::More;

my $pkg;

BEGIN {
    $pkg = 'Catmandu::Fix::publication_identifier';
    use_ok $pkg;
}
require_ok $pkg;

is_deeply $pkg->new()->fix(
    {
        publication_identifier => [
            {type  => 'isbn', value => '1234567890'},
            {type  => 'isbn', value => '0987654321'},
            {type  => 'issn', value => '12345678'},
            {value => 'test'},
        ]
    }
    ),
    {
    publication_identifier => {
        isbn    => ['1234567890', '0987654321'],
        issn    => ['12345678'],
        unknown => ['test'],
    }
    },
    "publication_identifier";

done_testing;
