package LibreCat::JobQueue;

use Catmandu::Sane;
use Gearman::XS qw(:constants);
use Gearman::XS::Client;
use JSON::MaybeXS;
use LibreCat::JobStatus;
use Moo;
use namespace::clean;

with 'Catmandu::Logger';

has gearman => (is => 'lazy');

sub _build_gearman {
    my $client = Gearman::XS::Client->new;
    $client->add_server('127.0.0.1', 4730);
    $client;
}

sub add_job {
    my ($self, $func, $workload) = @_;
    my ($ret, $job_id)
        = $self->gearman->do_background($func, encode_json($workload));
    if ($ret != GEARMAN_SUCCESS) {
        Catmandu::Error->throw($self->gearman->error);
    }
    $job_id;
}

sub job_status {
    my ($self, $job_id) = @_;
    my ($ret,  @status) = $self->gearman->job_status($job_id);
    if ($ret != GEARMAN_SUCCESS) {
        Catmandu::Error->throw($self->gearman->error);
    }
    LibreCat::JobStatus->new(\@status);
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
