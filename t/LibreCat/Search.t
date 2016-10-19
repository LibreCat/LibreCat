use strict;
use warnings;
use Test::More;
use Test::Exception;

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
dies_ok { $pkg->new(unknown => 1) } "unknown parameter";
lives_ok { $pkg->new(bag => 'publication') } "lives ok: param bag";

my $searcher = $pkg->new(bag => 'publication');
can_ok $searcher, $_ for qw(search default_facets sru_sort);

is ref $searcher->default_facets, 'HASH', "default facets return hash";

is $searcher->sru_sort("title.asc"), "title,,1", "title asc";
is $searcher->sru_sort("year.desc"), "year,,0", "year desc";
ok ! $searcher->sru_sort("field.whatever"), "no match";
ok ! $searcher->sru_sort("field:whatever"), "no match";
is $searcher->sru_sort(["title.asc","year.desc"]), "title,,1 year,,0", "title asc and year desc";

#my $hits = $searcher->search({});
#isa_ok $hits, 'Catmandu::Hits';

done_testing;
