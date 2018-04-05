use Catmandu::Sane;
use Test::More;
use Path::Tiny;
use LibreCat load => (layer_paths => [qw(t/layer)]);

{
    my $loaded = LibreCat->loaded;
    like $loaded, qr/0|1/;
}

isa_ok(
    LibreCat->user,
    "LibreCat::Model::User",
    "LibreCat->user returns a LibreCat::Model::User"
);

{
    LibreCat->publication->purge_all;

    like(LibreCat->publication->generate_id,
        qr{^[A-Z0-9-]+$}, 'publication generate id');

    my $pub = Catmandu->importer('YAML',
        file => 't/records/valid-publication.yml')->first;
    my $id = $pub->{_id};

    $pub->{title} = '我能吞下玻璃而不伤身体';

    ok(LibreCat->publication->add($pub), 'publication add');

    is $pub->{title}, '我能吞下玻璃而不伤身体',
        '..check title (return value)';

    is(
        LibreCat->publication->get($id)->{title},
        '我能吞下玻璃而不伤身体',
        '..check title (main)'
    );

    is(
        LibreCat->publication->search_bag->get($id)->{title},
        '我能吞下玻璃而不伤身体',
        '..check title (index)'
    );

    $pub->{title}
        = 'मैं काँच खा सकता हूँ और मुझे उससे कोई चोट नहीं पहुंचती';

    my $saved_record = LibreCat->publication->store($pub);

    ok $saved_record , 'publication add (skip index)';

    is $saved_record->{title},
        'मैं काँच खा सकता हूँ और मुझे उससे कोई चोट नहीं पहुंचती',
        '..check title (return value)';

    is(
        LibreCat->publication->get($id)->{title},
        'मैं काँच खा सकता हूँ और मुझे उससे कोई चोट नहीं पहुंचती',
        '..check title (main)'
    );

    is(
        LibreCat->publication->search_bag->get($id)->{title},
        '我能吞下玻璃而不伤身体',
        '..check title (index)'
    );

    my $indexed_record = LibreCat->publication->index($pub);

    ok $indexed_record , 'publication index';

    is $indexed_record->{title},
        'मैं काँच खा सकता हूँ और मुझे उससे कोई चोट नहीं पहुंचती',
        '..check title (return value)';

    is(
        LibreCat->publication->get($id)->{title},
        'मैं काँच खा सकता हूँ और मुझे उससे कोई चोट नहीं पहुंचती',
        '..check title (main)'
    );

    is(
        LibreCat->publication->search_bag->get($id)->{title},
        'मैं काँच खा सकता हूँ और मुझे उससे कोई चोट नहीं पहुंचती',
        '..check title (index)'
    );

    ok(
        LibreCat->publication->delete($id),
        'delete existing publication returns id'
    );
    ok(
        !LibreCat->publication->delete(99999999999),
        'delete non existing publication returns nil'
    );

    is(LibreCat->publication->get($id)->{status},
        'deleted', '..check title (main)');

    is(LibreCat->publication->search_bag->get($id)->{status},
        'deleted', '..check title (index)');

    ok(
        LibreCat->publication->purge($id),
        'purge existing publication returns id'
    );
    ok(
        !LibreCat->publication->purge(99999999999),
        'purge non existing publication returns nil'
    );

    ok(!LibreCat->publication->get($id), '...purged (main)');

    ok(!LibreCat->publication->search_bag->get($id), '...purged (index)');
}

# hooks

{
    my $hook = LibreCat->hook('eat');
    is scalar(@{$hook->before_fixes}), 2;
    is scalar(@{$hook->after_fixes}),  1;
    my $data = {};
    $hook->fix_before($data);
    is_deeply($data, {peckish => 1, hungry => 1});
    $hook->fix_after($data);
    is_deeply($data, {satisfied => 1});
}

{
    my $hook = LibreCat->hook('idontexist');

    is scalar(@{$hook->before_fixes}), 0;
    is scalar(@{$hook->after_fixes}),  0;

    my $data = {foo => 'bar'};
    $hook->fix_before($data);
    is_deeply($data, {foo => 'bar'});
}

done_testing;
