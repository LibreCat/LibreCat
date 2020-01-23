use Mojo::Base -strict;
use Path::Tiny;
use LibreCat -self, -load => {layer_paths => [qw(t/layer)]};
use Test::Mojo;
use Test::More;

# clean DBs
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

my $token = librecat->token->encode({foo => 'bar'});

# Start a Mojolicious app
my $t = Test::Mojo->new('LibreCat::Application');

subtest "get documentation" => sub {
    $t->get_ok('/v1/openapi.json')->status_is(200)->json_has('/basePath');
    $t->get_ok('/v1/openapi.json')->status_is(200);
};

subtest "authentication" => sub {
    $t->get_ok('/v1/user/1')->status_is(401);

    $t->get_ok('/v1/user/1' => {Authorization => 'invalid-key'})
        ->status_is(401)->json_has('/errors');

    # authorization ok, but not user in DB
    $t->get_ok('/v1/user/1' => {Authorization => $token})->status_is(404)
        ->json_has('/errors');
};

subtest "invalid model" => sub {
    $t->get_ok('/v1/ugly/123' => {Authorization => $token})
        ->status_is(404);
};

subtest "get non-existent user" => sub {
    $t->get_ok('/v1/user/91919192882' => {Authorization => $token})
        ->status_is(404)->json_has('/errors')
        ->json_is('/errors/0/title', 'user 91919192882 not found');
};

subtest "add/get/search/delete user" => sub {
    my $user = Catmandu->importer('YAML', file => "t/records/valid-user.yml")
        ->first;

    $t->post_ok('/v1/user' => {Authorization => $token} => json => $user)
        ->status_is(201)->json_is('/data/id', 999111999);

    $t->get_ok('/v1/user/999111999' => {Authorization => $token})
        ->status_is(200)->json_has('/data/attributes')
        ->json_is('/data/id',                   999111999)
        ->json_is('/data/attributes/full_name', 'User, Test');

    $t->get_ok('/api/v1/user/search' => {Authorization => $token})
        ->status_is(200)->json_has('/data/attributes');

    $t->get_ok('/api/v1/user/999111999/versions' => {Authorization => $token})
        ->status_is(404);

    $t->get_ok(
        '/v1/user/999111999/version/2' => {Authorization => $token})
        ->status_is(404);

    $t->delete_ok('/v1/user/999111999' => {Authorization => $token})
        ->status_is(200)->json_has('/data/attributes')
        ->json_is('/data/id'                => 999111999)
        ->json_is('/data/attributes/status' => 'deleted');

    ok !librecat->user->get(999111999), "user not in DB";
};

subtest "add invalid user" => sub {
    my $user
        = Catmandu->importer('YAML', file => "t/records/invalid-user.yml")
        ->first;

    $t->post_ok('/v1/user' => {Authorization => $token} => json => $user)
        ->status_is(400)->json_has('/errors');
};

subtest "get non-existent publication" => sub {

    $t->get_ok('/v1/publication/101010101' => {Authorization => $token})
        ->status_is(404)->json_has('/errors')
        ->json_is('/errors/0/title', 'publication 101010101 not found');
};

subtest "add/get/search/delete publication" => sub {
    my $pub = Catmandu->importer('YAML',
        file => "t/records/valid-publication.yml")->first;

    $t->post_ok(
        '/v1/publication' => {Authorization => $token} => json => $pub)
        ->status_is(201)->json_is('/data/id', 999999999);

    $t->put_ok('/v1/publication/999999999' => {Authorization => $token} =>
            json => $pub)->status_is(200)->json_is('/data/id', 999999999);

    # Change the pub record id and check for errors
    $pub->{_id} = '1234567890';

    $t->put_ok('/v1/publication/999999999' => {Authorization => $token} =>
            json => $pub)->status_is(400)->json_is(
        '/errors/0/validation_error/0',
        "id in request and data don't match"
            );

    $t->get_ok('/v1/publication/999999999' => {Authorization => $token})
        ->status_is(200)->json_has('/data/attributes')
        ->json_is('/data/id',             999999999)
        ->json_is('/data/attributes/doi', '10.1093/jxb/erv066');

    $t->patch_ok(
        '/v1/publication/999999999' => {Authorization => $token} =>
            json => {title => 'Test patch request'})->status_is(200)
        ->json_is('/data/id',               999999999)
        ->json_is('/data/attributes/title', 'Test patch request');

    # Patch with a wrong id
    $t->patch_ok(
        '/v1/publication/999999999' => {Authorization => $token} =>
            json => {_id => '1234567890'})->status_is(400)->json_is(
        '/errors/0/validation_error/0',
        "id in request and data don't match"
            );

    $t->get_ok(
        '/v1/publication/999999999/versions' => {Authorization => $token})
        ->status_is(200)->json_is('/data/id', 999999999)
        ->json_is('/data/attributes/0/_version', '3');

    $t->get_ok('/v1/publication/999999999/version/1' =>
            {Authorization => $token})->status_is(200)
        ->json_is('/data/id',                  999999999)
        ->json_is('/data/attributes/_version', '1');

    $t->get_ok('/api/v1/publication/search' => {Authorization => $token})
        ->status_is(200)->json_has('/data/attributes')
        ->json_hasnt('/data/attributes/aggs');

    $t->get_ok(
        '/api/v1/publication/search?aggs=1' => {Authorization => $token})
        ->status_is(200)->json_has('/data/attributes')
        ->json_has('/data/attributes/aggs');

    $t->delete_ok(
        '/v1/publication/999999999' => {Authorization => $token})
        ->status_is(200)->json_has('/data/attributes')
        ->json_is('/data/id'                => 999999999)
        ->json_is('/data/attributes/status' => 'deleted');

    ok !librecat->publication->get(999111999), "publication  not in DB";
};

subtest "not_found" => sub {
    $t->get_ok('/v1/projication' => {Authorization => $token})
        ->status_is(404)->json_is('/errors',[{ status => 404, id => "route_not_found", title => "route not found" }]);
};

done_testing;
