use Catmandu::Sane;
use LibreCat -load => {layer_paths => [qw(t/layer)]};
use Test::More;
use warnings FATAL => 'all';

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Dedup::Publication';
    use_ok $pkg;
};

require_ok $pkg;

# empty db
Catmandu->store('main')->bag('publication')->delete_all;
Catmandu->store('search')->bag('publication')->delete_all;

my $record = Catmandu->importer('YAML', file => 't/records/valid-publication.yml')->first;

Catmandu->store('main')->bag('publication')->add($record);
Catmandu->store('main')->bag('publication')->commit;
Catmandu->store('search')->bag('publication')->add($record);
Catmandu->store('search')->bag('publication')->commit;

my $detector = $pkg->new();

my $data = {
    doi => '10.1093/jxb/erv066',
    isi => '000356223900015',
    pmid => '25740929',
};

is $detector->has_duplicate($data), 1;

is_deeply $detector->find_duplicate($data), ("999999999");

END {
    # cleaning up
    Catmandu->store('main')->bag('publication')->delete_all;
    Catmandu->store('search')->bag('publication')->delete_all;
}

done_testing;
