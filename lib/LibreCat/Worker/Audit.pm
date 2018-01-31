package LibreCat::Worker::Audit;

use Catmandu::Sane;
use Catmandu;
use Moo;
use namespace::clean;

with 'LibreCat::Worker';

sub work {
    my ($self, $opts) = @_;

    my $store = Catmandu->store('main')->bag('audit');

    unless ($store) {
        $self->log->error("failed to find 'main.audit' store");
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

_END__

=pod

=head1 NAME

LibreCat::Worker::Audit - a worker for audits (if configured)

=head1 SYNOPSIS

    use LibreCat::Worker::Audit;

    my $audit = LibreCat::Worker::Audit->new;
    $audit->work({
        id      => $opts->{id},
        bag     => $opts->{bag},
        process => $opts->{process},
        action  => $opts->{action},
        message => $opts->{message},
        time    => time
    });

    # or better queue it via helper functions

    use LibreCat::App::Helper;

    my $job = {{
        id      => $opts->{id},
        bag     => $opts->{bag},
        process => $opts->{process},
        action  => $opts->{action},
        message => $opts->{message},
        time    => time
    }

    h->queue->add_job('mailer', $job)

=head2 SEE ALSO

L<LibreCat::Worker>

=cut
