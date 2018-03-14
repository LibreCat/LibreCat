use Catmandu::Sane;
use LibreCat load => (layer_paths => [qw(t/layer)]);
use Test::More;
use Test::Exception;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Index';
    use_ok $pkg;
}

require_ok $pkg;

my $index = $pkg->new;

ok $index , 'new';

ok $index->is_availabe, "is_availabe";

ok $index->initialize, "initialize";

ok $index->active, "active";

ok $index->has_index('librecat_test1'), 'has_index(librecat_test1)';

ok $index->has_index('librecat_test2'), 'has_index(librecat_test2)';

ok $index->has_alias('librecat_test1', 'librecat'),
    'has_alias(librecat_test1,librecat)';

my $status = $index->get_status;

ok $status , 'get_status';

is $status->{configured_index_name}, 'librecat_test', "$pkg is layer aware";

is_deeply $status ,
    {
    'configured_index_name' => 'librecat_test',
    'active_index'          => 'librecat_test1',
    'number_of_indices'     => 2,
    'alias'                 => 'librecat_test',
    'all_indices'           => ['librecat_test1', 'librecat_test2',]
    },
    'correct status';

ok $index->switch, "switch";

$status = $index->get_status;

is_deeply $status ,
    {
    'configured_index_name' => 'librecat_test',
    'active_index'          => 'librecat_test2',
    'number_of_indices'     => 2,
    'alias'                 => 'librecat_test',
    'all_indices'           => ['librecat_test1', 'librecat_test2']
    },
    'correct status';

done_testing;
