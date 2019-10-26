package LibreCat::JobQueue;

use Catmandu::Sane;
use Gearman::Client;
use JSON::MaybeXS;
use LibreCat::JobStatus;
use Moo;
use namespace::clean;

with 'Catmandu::Logger';

has gearman => (is => 'lazy');

sub _build_gearman {
    my $client = Gearman::Client->new;
    $client->job_servers({host => '127.0.0.1', port => 4730});
    $client;
}

sub add_job {
    my ($self, $func, $workload) = @_;
    # TODO add callbacks in options hash
    $self->gearman->dispatch_background($func, encode_json($workload), {}) //
        Catmandu::Error->throw("couldn't dispatch job '$func'");
}

sub job_status {
    my ($self, $job_id) = @_;
    my ($status) = $self->gearman->get_status($job_id);
    if (!$status) {
        Catmandu::Error->throw("couldn't get status for job '$job_id'");
    }
    LibreCat::JobStatus->new([$status->known, $status->running, $status->progress, $status->percent]);
}

1;

__END__

=pod

=head1 NAME

LibreCat::JobQueue - a job queue for LibreCat processes

=head1 SYNOPSIS

    use LibreCat::JobQueue;

    my $queue = LibreCat::JobQueue->new;

    my $job = $queue->add_job('mailer', {
            to => 'patrick.hochstenbach@ugent.be' ,
            from => 'patrick.hochstenbach@ugent.be' ,
            subject => 'test' ,
            body => 'test' ,
    });

    while (1) {
        my $s        = $queue->job_status($job);
        my $running  = $s->running;
        print "%s is running? %s\n" , $job , $running ? 'YES' : NO;
        sleep(1);
    }

=cut
