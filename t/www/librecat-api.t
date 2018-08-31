use Mojo::Base -strict;

use Path::Tiny;
use lib path(__FILE__)->parent->parent->child('lib')->stringify;
use LibreCat -self, -load => {layer_paths => [qw(t/layer)]};

use Test::Mojo;
use Test::More;

# preload
for my $bag (qw(publication department project research_group user)) {
    note("deleting backup $bag");
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

subtest "add/get/delete user" => sub {
    my $user = Catmandu->importer('YAML', file => "t/records/valid-user.yml")->first;

    $t->get_ok('/api/user/999111999')
        ->status_is(404);

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

# subtest "add invalid user" => sub {
#     my $user = Catmandu->importer('YAML', file => "t/records/invalid-user.yml")->first;
#
#     $t->post_ok('/api/user' => json => $user)
#         ->status_is(400)
#         ->json_is('/data/id', 'xxx')
#         ->json_is('/data/model', 'yyy')
#         ->json_has('/data/error');
# };


done_testing;
