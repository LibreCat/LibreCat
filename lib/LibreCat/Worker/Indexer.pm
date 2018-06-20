package LibreCat::Worker::Indexer;

use Catmandu::Sane;
use Catmandu;
use Moo;
use namespace::clean;

with 'LibreCat::Worker';

sub work {
    my ($self, $opts, $job) = @_;

    $self->log->debug("entering indexer");

    my $bag = $opts->{bag};
    my $id  = $opts->{id};

    unless ($id) {
        $self->log->error("no record $bag($id) found!");
        return;
    }

    my $source = Catmandu->store('main')->bag($bag);
    my $target = Catmandu->store('search')->bag($bag);

    $self->log->debug("index one $bag : $id");

    if (my $rec = $source->get($id)) {
        $self->log->info("indexing $bag 1/1");
        $rec = $target->add($rec);
        $self->log->debug(Catmandu->export_to_string($rec));
        $target->commit;
        $job->send_status(1, 1);
        $self->log->info("indexed 1");
    }
    else {
        $self->log->error("no record $bag($id) found!");
    }
}

1;

__END__

=pod

=head1 NAME

LibreCat::Worker::Indexer - an indexing worker

=cut
