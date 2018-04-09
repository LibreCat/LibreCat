use Catmandu::Sane;
use Test::More;
use Path::Tiny;
use LibreCat -load => {layer_paths => [qw(t/layer)]};

{
    my $loaded = LibreCat->loaded;
    like $loaded, qr/0|1/;
}

my $instance = LibreCat->instance;

isa_ok(
    $instance->model('user'),
    "LibreCat::Model::User",
    "librecat->user returns a LibreCat::Model::User"
);

{

    my $model = $instance->model('publication');

    $model->purge_all;

    like($model->generate_id,
        qr{^[A-Z0-9-]+$}, 'publication generate id');

    my $pub = Catmandu->importer('YAML',
        file => 't/records/valid-publication.yml')->first;
    my $id = $pub->{_id};

    $pub->{title} = '我能吞下玻璃而不伤身体';

    ok($model->add($pub), 'publication add');

    is $pub->{title}, '我能吞下玻璃而不伤身体',
        '..check title (return value)';

    is(
        $model->get($id)->{title},
        '我能吞下玻璃而不伤身体',
        '..check title (main)'
    );

    is(
        $model->search_bag->get($id)->{title},
        '我能吞下玻璃而不伤身体',
        '..check title (index)'
    );

    $pub->{title}
        = 'मैं काँच खा सकता हूँ और मुझे उससे कोई चोट नहीं पहुंचती';

    my $saved_record = $model->store($pub);

    ok $saved_record , 'publication add (skip index)';

    is $saved_record->{title},
        'मैं काँच खा सकता हूँ और मुझे उससे कोई चोट नहीं पहुंचती',
        '..check title (return value)';

    is(
        $model->get($id)->{title},
        'मैं काँच खा सकता हूँ और मुझे उससे कोई चोट नहीं पहुंचती',
        '..check title (main)'
    );

    is(
        $model->search_bag->get($id)->{title},
        '我能吞下玻璃而不伤身体',
        '..check title (index)'
    );

    my $indexed_record = $model->index($pub);

    ok $indexed_record , 'publication index';

    is $indexed_record->{title},
        'मैं काँच खा सकता हूँ और मुझे उससे कोई चोट नहीं पहुंचती',
        '..check title (return value)';

    is(
        $model->get($id)->{title},
        'मैं काँच खा सकता हूँ और मुझे उससे कोई चोट नहीं पहुंचती',
        '..check title (main)'
    );

    is(
        $model->search_bag->get($id)->{title},
        'मैं काँच खा सकता हूँ और मुझे उससे कोई चोट नहीं पहुंचती',
        '..check title (index)'
    );

    ok(
        $model->delete($id),
        'delete existing publication returns id'
    );
    ok(
        !$model->delete(99999999999),
        'delete non existing publication returns nil'
    );

    is($model->get($id)->{status},
        'deleted', '..check title (main)');

    is($model->search_bag->get($id)->{status},
        'deleted', '..check title (index)');

    ok(
        $model->purge($id),
        'purge existing publication returns id'
    );
    ok(
        !$model->purge(99999999999),
        'purge non existing publication returns nil'
    );

    ok(!$model->get($id), '...purged (main)');

    ok(!$model->search_bag->get($id), '...purged (index)');
}

# hooks

{
    my $hook = $instance->hook('eat');
    is scalar(@{$hook->before_fixes}), 2;
    is scalar(@{$hook->after_fixes}),  1;
    my $data = {};
    $hook->fix_before($data);
    is_deeply($data, {peckish => 1, hungry => 1});
    $hook->fix_after($data);
    is_deeply($data, {satisfied => 1});
}

{
    my $hook = $instance->hook('idontexist');

    is scalar(@{$hook->before_fixes}), 0;
    is scalar(@{$hook->after_fixes}),  0;

    my $data = {foo => 'bar'};
    $hook->fix_before($data);
    is_deeply($data, {foo => 'bar'});
}

done_testing;
