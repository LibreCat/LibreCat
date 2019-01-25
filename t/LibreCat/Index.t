use Catmandu::Sane;
use LibreCat -load => {layer_paths => [qw(t/layer)]};
use Test::More;
use Test::Exception;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Index';
    use_ok $pkg;
}

require_ok $pkg;

my $pub_idx = 'librecat_test_publication';

my $index = $pkg->new;

ok $index , 'new';

ok $index->is_availabe, "is_availabe";

ok $index->initialize, "initialize";

ok $index->active($pub_idx), "active";

ok $index->has_index("${pub_idx}_1"), "has_index(${pub_idx}_1)";

ok $index->has_index("${pub_idx}_2"), "has_index(${pub_idx}_2)";

ok $index->has_alias("${pub_idx}_1", $pub_idx),
    "has_alias(${pub_idx}_1, $pub_idx)";

my $status = $index->status_for($pub_idx);

ok $status , 'status_for';

is $status->{configured_index_name}, $pub_idx, "$pkg is layer aware";

is_deeply $status,
    {
    'configured_index_name' => $pub_idx,
    'active_index'          => "${pub_idx}_1",
    'number_of_indices'     => 2,
    'alias'                 => $pub_idx,
    'all_indices'           => ["${pub_idx}_1", "${pub_idx}_2",]
    },
    'correct status';

ok $index->switch($pub_idx), "switch";

$status = $index->status_for($pub_idx);

is_deeply $status ,
    {
    'configured_index_name' => $pub_idx,
    'active_index'          => "${pub_idx}_2",
    'number_of_indices'     => 2,
    'alias'                 => $pub_idx,
    'all_indices'           => ["${pub_idx}_1", "${pub_idx}_2",]
    },
    'correct status';

$index->initialize;

done_testing;
