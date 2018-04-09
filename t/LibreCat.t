use Catmandu::Sane;
use POSIX qw(strftime);
use Test::More;
use Test::Exception;
use LibreCat;

# class methods and loading

ok(LibreCat->loaded == 0);

dies_ok { LibreCat->instance } qr/must be loaded first/i;

LibreCat->load({layer_paths => [qw(t/layer)]});

ok(LibreCat->loaded == 1);

my $instance = LibreCat->instance;

ok($instance == LibreCat->instance, "instance is a singleton");

# config

is(ref $instance->config, 'HASH');
ok($instance->config == Catmandu->config, "LibreCat and Catmandu share a config hash");

# models
ok($instance->has_model('user') == 1);
ok($instance->has_model('gremlin') == 0);

isa_ok(
    $instance->model('user'),
    "LibreCat::Model::User",
    "librecat->user returns a LibreCat::Model::User"
);

{

    my $model = $instance->model('publication');

    isa_ok(
        $instance->model('publication'),
        "LibreCat::Model::Publication",
        "librecat->publication returns a LibreCat::Model::Publication"
    );

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

# timestamp

{
    my $time = time;
    my $str = $instance->timestamp($time);
    is($str, strftime('%Y-%m-%dT%H:%M:%SZ', gmtime($time)));

    $instance->config->{time_format} = '%Y-%m-%d';
    $str = $instance->timestamp($time);
    is($str, strftime('%Y-%m-%d', gmtime($time)));

    ok($instance->timestamp, 'time argument is optional');
}

# searcher

isa_ok(
    $instance->searcher,
    "LibreCat::Search",
    "librecat->search returns a LibreCat::Search"
);

# queue

isa_ok(
    $instance->queue,
    "LibreCat::JobQueue"
);

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
