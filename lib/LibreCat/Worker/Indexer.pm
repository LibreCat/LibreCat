package LibreCat::Worker::Indexer;

use Catmandu::Sane;
use Catmandu;
use Moo;
use namespace::clean;

with 'LibreCat::Worker';

sub worker_functions { [qw(index_record index_all)] }

sub index_record {
    my ($self, $opts) = @_;
    my $bag = Catmandu->store->bag($opts->{bag});
    my $search_bag = Catmandu->store('search')->bag($opts->{bag});
    if (my $rec = $bag->get($opts->{id})) {
        $self->log->info("indexing $opts->{bag} $opts->{id}");
        $search_bag->add($rec);
        $search_bag->commit;
    }
}

sub index_all {
    my ($self, $opts, $job) = @_;
    my $bag = Catmandu->store->bag($opts->{bag});
    my $search_bag = Catmandu->store('search')->bag($opts->{bag});
    my $total = $bag->count;
    my $n = 0;
    $search_bag->add_many($bag->tap(sub {
        if (++$n % 500 == 0) {
            $self->log->info("indexing $opts->{bag} $n/$total");
            $job->send_status($n, $total);
        }
    }));
    $search_bag->commit;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Worker::Indexer - an indexing worker

=cut

