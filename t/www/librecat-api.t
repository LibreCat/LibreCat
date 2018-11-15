use Mojo::Base -strict;

use Path::Tiny;
use lib path(__FILE__)->parent->parent->child('lib')->stringify;
use LibreCat -self, -load => {layer_paths => [qw(t/layer)]};

use Test::Mojo;
use Test::More;

<<<<<<< HEAD
# preload
for my $bag (qw(publication department project research_group user)) {
    note("deleting main $bag");
    {
        my $store = Catmandu->store('main')->bag($bag);
        $store->delete_all;
        $store->commit;
    }

    note("deleting version $bag");
    {
        my $store = Catmandu->store('main')->bag("$bag\_version");
        $store->delete_all;
        $store->commit;
    }

    note("deleting search $bag");
    {
        my $store = Catmandu->store('search')->bag($bag);
        $store->delete_all;
        $store->commit;
    }
}

# Start a Mojolicious app
my $t = Test::Mojo->new('LibreCat::Application');

# subtest "no auth token" => sub {
#     $t->get_ok("/api/user/1")
#         ->status_is(401);
#     $t->get_ok("/api/user/1?token=1234")
#         ->status_is(404);
# };

subtest "get non-existent user" => sub {
    $t->get_ok('/api/user/91919192882')->status_is(404)->json_has('/errors')
=======
# Start a Mojolicious app
my $t = Test::Mojo->new('LibreCat::Application');

subtest "get non-existent user" => sub {
    $t->get_ok('/api/user/91919192882')
        ->status_is(404)
        ->json_has('/errors')
>>>>>>> 6f36f45467ad852b3b1eb36487312f9a87745709
        ->json_is('/errors/0/title', 'user 91919192882 not found');
};

subtest "add/get/delete user" => sub {
<<<<<<< HEAD
    my $user = Catmandu->importer('YAML', file => "t/records/valid-user.yml")
        ->first;

    $t->post_ok('/api/user' => json => $user)->status_is(200)
        ->json_is('/data/id', 999111999);

    $t->get_ok('/api/user/999111999')->status_is(200)
        ->json_has('/data/attributes')->json_is('/data/id', 999111999)
        ->json_is('/data/attributes/full_name', 'User, Test');

    $t->get_ok('/api/user/999111999/versions')->status_is(404);

    $t->get_ok('/api/user/999111999/version/2')->status_is(404);

    $t->delete_ok('/api/user/999111999')->status_is(200)
        ->json_has('/data/attributes')->json_is('/data/id' => 999111999)
        ->json_is('/data/attributes/status' => 'deleted');

    ok !librecat->user->get(999111999), "user  not in DB";
};

subtest "add invalid user" => sub {
    my $user
        = Catmandu->importer('YAML', file => "t/records/invalid-user.yml")
        ->first;

    $t->post_ok('/api/user' => json => $user)->status_is(400)
=======
    my $user = Catmandu->importer('YAML', file => "t/records/valid-user.yml")->first;

    $t->post_ok('/api/user' => json => $user)
        ->status_is(200)
        ->json_is('/data/id', 999111999);

    $t->get_ok('/api/user/999111999')
        ->status_is(200)
        ->json_has('/data/attributes')
        ->json_is('/data/id', 999111999)
        ->json_is('/data/attributes/full_name', 'User, Test');

    $t->delete_ok('/api/user/999111999')
        ->status_is(200)
        ->json_has('/data/attributes')
        ->json_is('/data/id' => 999111999)
        ->json_is('/data/attributes/status' => 'deleted');

    ok ! librecat->user->get(999111999), "user  not in DB";
};

subtest "add invalid user" => sub {
    my $user = Catmandu->importer('YAML', file => "t/records/invalid-user.yml")->first;

    $t->post_ok('/api/user' => json => $user)
        ->status_is(400)
>>>>>>> 6f36f45467ad852b3b1eb36487312f9a87745709
        ->json_has('/errors');
};

subtest "get non-existent publication" => sub {
<<<<<<< HEAD
    $t->get_ok('/api/publication/101010101')->status_is(404)
=======
    $t->get_ok('/api/publication/101010101')
        ->status_is(404)
>>>>>>> 6f36f45467ad852b3b1eb36487312f9a87745709
        ->json_has('/errors')
        ->json_is('/errors/0/title', 'publication 101010101 not found');
};

subtest "add/get/delete publication" => sub {
<<<<<<< HEAD
    my $pub = Catmandu->importer('YAML',
        file => "t/records/valid-publication.yml")->first;

    $t->post_ok('/api/publication' => json => $pub)->status_is(200)
        ->json_is('/data/id', 999999999);

    $t->get_ok('/api/publication/999999999')->status_is(200)
        ->json_has('/data/attributes')->json_is('/data/id', 999999999)
        ->json_is('/data/attributes/doi', '10.1093/jxb/erv066');

    $t->patch_ok('/api/publication/999999999' => json =>
            {title => 'Test patch request'})->status_is(200)
        ->json_is('/data/id',               999999999)
        ->json_is('/data/attributes/title', 'Test patch request');

    $t->get_ok('/api/publication/999999999/versions')->status_is(200)
        ->json_is('/data/id',                    999999999)
        ->json_is('/data/attributes/0/_version', '2');

    $t->get_ok('/api/publication/999999999/version/1')->status_is(200)
        ->json_is('/data/id',                  999999999)
        ->json_is('/data/attributes/_version', '1');

    $t->delete_ok('/api/publication/999999999')->status_is(200)
        ->json_has('/data/attributes')->json_is('/data/id' => 999999999)
        ->json_is('/data/attributes/status' => 'deleted');

    ok !librecat->publication->get(999111999), "publication  not in DB";
=======
    my $pub = Catmandu->importer('YAML', file => "t/records/valid-publication.yml")->first;

    $t->post_ok('/api/publication' => json => $pub)
        ->status_is(200)
        ->json_is('/data/id', 999999999);

    $t->get_ok('/api/publication/999999999')
        ->status_is(200)
        ->json_has('/data/attributes')
        ->json_is('/data/id', 999999999)
        ->json_is('/data/attributes/doi', '10.1093/jxb/erv066');

    $t->delete_ok('/api/publication/999999999')
        ->status_is(200)
        ->json_has('/data/attributes')
        ->json_is('/data/id' => 999999999)
        ->json_is('/data/attributes/status' => 'deleted');

    ok ! librecat->publication->get(999111999), "publication  not in DB";
>>>>>>> 6f36f45467ad852b3b1eb36487312f9a87745709
};

done_testing;
