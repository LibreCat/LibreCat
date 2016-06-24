use Test::Lib;
use TestHeader;

Catmandu->load('.');

my $pkg;

BEGIN {
    $pkg = 'Catmandu::Fix::external_id';
    use_ok $pkg;
}
require_ok $pkg;

is_deeply $pkg->new()->fix({
    external_id => [
        { type => 'pmid' , value => '1234567890' } ,
        { type => 'pmid' , value => '0987654321' } ,
        { type => 'arxiv' , value => '12345678'  } ,
        { type => '' , value => 'bla' } ,
    ]
}) , {
    external_id =>  {
        pmid    => '1234567890'  ,
        arxiv   => '12345678' ,
        unknown => 'bla'
    } ,
}, "external_id";

done_testing;
