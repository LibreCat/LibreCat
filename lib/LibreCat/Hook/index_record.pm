package LibreCat::Hook::index_record;

use Catmandu::Sane;
use LibreCat::App::Helper;
use Dancer qw(:syntax);
use Moo;

has bag => (is => 'ro', required => 1);

sub fix {
    my ($self, $data) = @_;

    my $bag = $self->bag;
    h->log->debug("entering index_record hook with bag $bag");
    my $id = $data->{_id};

    my $job = {id => $data->{_id}, bag => $bag,};

    h->log->error("adding job indexer: " . to_yaml($job));
    try {
        h->queue->add_job('indexer', $job);
    }
    catch {
        h->log->trace("caught a : $_");
    };

}

1;
