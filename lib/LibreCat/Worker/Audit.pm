package LibreCat::Worker::Audit;

use Catmandu::Sane;
use Catmandu;
use Moo;
use namespace::clean;

with 'LibreCat::Worker';

sub work {
    my ($self, $opts) = @_;

    my $store = Catmandu->store('backup')->bag('audit');

    unless ($store) {
        $self->log->error("failed to find 'backup.audit' store");
        return;
    }

    $self->log->debugf("audit message: %s", $opts);

    my $rec = {
        id      => $opts->{id},
        bag     => $opts->{bag},
        process => $opts->{process},
        action  => $opts->{action},
        message => $opts->{message},
        time    => time
    };

    $store->add($rec);

    $store->commit();
}

1;
