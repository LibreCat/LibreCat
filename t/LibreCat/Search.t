use strict;
use warnings FATAL => 'all';
use Test::More;
use Test::Exception;
use Catmandu::Store::Hash;
use LibreCat::Search;
use Data::Dumper;

my $pkg;

BEGIN {
    use Catmandu::Sane;
    use Path::Tiny;
    use lib path(__FILE__)->parent->parent->child('lib')->stringify;
    use LibreCat::Layers;

    LibreCat::Layers->new(layer_paths => [qw(t/layer)])->load;

    $pkg = 'LibreCat::Search';
    use_ok $pkg;
}

require_ok $pkg;
dies_ok { $pkg->new() } "params required";
#dies_ok { $pkg->new(store => 'blabla') } "is Catmandu store";
lives_ok { $pkg->new(store => Catmandu::Store::Hash->new()) } "store param";

my $store = Catmandu->store('search');
my $searcher = $pkg->new(store => $store);
can_ok $searcher, 'search';

# prepare test index
$store->drop;
my $importer = Catmandu->importer('YAML', file => 't/records/valid-publication.yml');
my $res = $store->bag('publication')->add($importer->first);
ok $store->bag('publication')->get('999999999'), "can get record";

ok ! $searcher->search('',{q => ["id=999999999"]});
ok ! $searcher->search('',{});

$store->drop;

is ref $searcher->_default_facets, 'HASH', "default facets return hash";
ok $searcher->_default_facets->{author}, "has author facet";

is $searcher->_sru_sort(""), "", "empty sort argument";
is $searcher->_sru_sort("title.asc"), "title,,1", "title asc";
is $searcher->_sru_sort("year.desc"), "year,,0", "year desc";
ok ! $searcher->_sru_sort("field.whatever"), "no match";
ok ! $searcher->_sru_sort("field:whatever"), "no match";
is $searcher->_sru_sort(["title.asc","year.desc"]), "title,,1 year,,0", "title asc and year desc";

done_testing;
