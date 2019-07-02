use Catmandu::Sane;
use Catmandu;
use LibreCat -self => -load => {layer_paths => [qw(t/layer)]};
use Test::More;
use Test::Exception;
use warnings FATAL => 'all';
use Data::Dumper;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Model::Publication';
    use_ok $pkg;
}

require_ok $pkg;

my $model = librecat->publication;

$model->delete_all;
$model->commit;

# version check

my $rec
    = Catmandu->importer('YAML', file => 't/records/valid-publication.yml')->first;

lives_ok { $model->add($rec) };

$rec = $model->get($rec->{_id});
$rec->{_version} += 1;
throws_ok { $model->add($rec) } 'LibreCat::Error::VersionConflict';

$model->delete_all;
$model->commit;

done_testing;
