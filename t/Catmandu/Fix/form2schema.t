use Catmandu::Sane;
use Test::More;
use Data::Dumper;

my $pkg;

BEGIN {
    $pkg = 'Catmandu::Fix::publication_identifier';
    use_ok $pkg;
}
require_ok $pkg;

is_deeply $pkg->new('publication_identifier')->fix(
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

is_deeply $pkg->new('external_id')->fix(
    {
        external_id => [
            {type => 'pmid',  value => '1234567890'},
            {type => 'pmid',  value => '0987654321'},
            {type => 'arxiv', value => '12345678'},
            {value => 'bla'},
        ]
    }
    ),
    {
        external_id => {
            pmid => ['1234567890', '0987654321'],
            arxiv => ['12345678'],
            unknown => ['bla']
        },
    },
    "external_id";

done_testing;
