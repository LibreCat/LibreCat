use Catmandu::Sane;
use Catmandu;
use Catmandu::Store::Hash;
use LibreCat load => (layer_paths => [qw(t/layer)]);
use Test::More;
use Test::Exception;
use Data::Dumper;

my $pkg;

BEGIN {
    $pkg = "Catmandu::Plugin::LibreCat::PublicationStore";
    use_ok $pkg;
}
require_ok $pkg;

my $store = Catmandu::Store::Hash->new(
    bags => {publication => {plugins => [qw(LibreCat::PublicationStore)]}});
my $bag = $store->bag('publication');

ok $store->does('Catmandu::Store'), 'create Catmandu-Store with plugin';

my $rec
    = Catmandu->importer('YAML', file => 't/records/valid-publication.yml')
    ->first;
my $id = $rec->{_id};

subtest 'add' => sub {
    ok $bag->add($rec), 'store valid publication';
    ok $bag->get($id),  'get stored record';
    is $bag->get($id)->{_id}, $id, 'record correct';
};

subtest 'add_many' => sub {
    ok $bag->add_many(
        Catmandu->importer('YAML', file => 'devel/publications.yml')),
        'add_many';
};

subtest 'delete' => sub {
    ok my $deleted = $bag->set_delete_status($rec->{_id}),
        'can set status to delete';
    is $deleted->{status}, 'deleted', 'status deleted';
    ok $deleted->{title}, 'title';
    ok $bag->get($rec->{_id}), 'can get record';
};

done_testing;
