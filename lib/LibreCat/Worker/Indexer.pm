package LibreCat::Worker::Indexer;

use Catmandu::Sane;
use Catmandu;
use Moo;
use namespace::clean;

with 'LibreCat::Worker';

sub work {
    my ($self, $opts, $job) = @_;

    $self->log->debug("entering indexer");

    if ($opts->{id}) {
        return $self->index_record($opts, $job);
    }
    else {
        return $self->index_all($opts, $job);
    }
}

sub index_record {
    my ($self, $opts, $job) = @_;

    my $bag = $opts->{bag};
    my $id  = $opts->{bag};

    my $source = Catmandu->store('backup')->bag($bag);
    my $target = Catmandu->store('search')->bag($bag);

    $self->log->debug("index one $bag : $id");

    if (my $rec = $source->get($id)) {
        $self->log->info("indexing $bag 1/1");
        $target->add($rec);
        $target->commit;
        $job->send_status(1, 1);
        $self->log->info("indexed 1");
    }
    else {
        $self->log->error("no record $bag($id) found!");
    }
}

sub index_all {
    my ($self, $opts, $job) = @_;

    my $bag = $opts->{bag};
    my $id  = $opts->{bag};

    my $source = Catmandu->store('backup')->bag($bag);
    my $target = Catmandu->store('search')->bag($bag);
    my $total  = $source->count;
    my $n      = 0;

    $self->log->debug("index all $bag");

    $target->add_many(
        $source->tap(
            sub {
                if (++$n % 500 == 0) {
                    $self->log->info("indexing $bag $n/$total");
                    $job->send_status($n, $total);
                }
            }
        )
    );

    $job->send_status($total, $total);
    $target->commit;

    $self->log->info("indexed $n");
}

1;

__END__

=pod

=head1 NAME

LibreCat::Worker::Indexer - an indexing worker

=cut
