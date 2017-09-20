use strict;
use warnings FATAL => 'all';
use LibreCat load => (layer_paths => [qw(t/layer)]);
use LibreCat::JobQueue;
use LibreCat::CLI;
use Test::More;
use Test::Exception;
use App::Cmd::Tester;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Worker::Indexer';
    use_ok $pkg;
}

require_ok $pkg;

lives_ok {$pkg->new()} "object creation";

my $worker = $pkg->new();

can_ok $worker, "work";

done_testing;

__END__
Catmandu->config->{queue} = {workers => {indexer => {count => 1}}};
# {
#     my $result = test_app(qq|LibreCat::CLI| => ['queue', 'start']);
#     ok ! $result->error, 'start worker via queue cmd';
#
#     $result = test_app(qq|LibreCat::CLI| => ['queue', 'status']);
#     like $result->output, qr/indexer/, "indexer worker running";
# }

# empty db
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

my $q = LibreCat::JobQueue->new;

my $rg = {_id => 1, name => "Indexing RG Test"};
my $stored_rg = Catmandu->store('main')->bag('research_group')->add($rg);
is $stored_rg->{name}, "Indexing RG Test", "stored name";

my $job_id = $q->add_job("indexer", {_id => 1, bag => 'research_group'});
ok $job_id, "job id";
my $status = $q->job_status($job_id);
ok $status->running || $status->done, "job status";
sleep 2;

TODO: {
    local $TODO = "bug in worker indexer?";
    my $indexed_rg = Catmandu->store('search')->bag('research_group')->get('1');
    is $indexed_rg, "Indexing RG Test", "indexed named";
};

#test_app(qq|LibreCat::CLI| => ['queue', 'stop']);

done_testing;
