package LibreCat::Cmd::queue;

use Catmandu::Sane;
use Catmandu;
use LibreCat::App::Helper;
use Carp;
use Net::Telnet::Gearman;

use parent 'LibreCat::Cmd';

sub command_opt_spec {
    my ($class) = @_;
    (['background|bg', ""], ['id=s', ""],);
}

sub description {
    return <<EOF;
Usage:

librecat queue status
librecat [--background] queue add_job WORKER FILE
librecat queue start
librecat queue stop

EOF
}

sub command {
    my ($self, $opts, $args) = @_;

    my $commands = qr/status|add_job|start|stop/;

    my $cmd = shift @$args;

    unless ($cmd =~ /^$commands$/) {
        $self->usage_error("should be one of $commands");
    }

    if ($cmd eq 'status') {
        $self->_status;
    }
    elsif ($cmd eq 'add_job') {
        $self->_add_job(@$args, background => $opts->background);
    }
    elsif ($cmd eq 'start') {
        $self->_daemon('start');
    }
    elsif ($cmd eq 'stop') {
        $self->_daemon('stop');
    }
}

sub _daemon {
    my ($self, $startstop) = @_;

    my $config = Catmandu->config->{queue} // {};

    croak "no queue.workers configured" unless exists $config->{workers};

    for my $worker (keys %{$config->{workers}}) {
        my $count     = $config->{workers}->{$worker}->{count}     // 0;
        my $supervise = $config->{workers}->{$worker}->{supervise} // 0;

        next unless $count > 0;

        my $cmd = "$0 worker $worker $startstop --workers $count";
        $cmd .= " --supervise" if $supervise;

        printf STDERR "%s $worker...",
            $startstop eq 'start' ? 'Starting' : 'Stopping';
        system($cmd);
        printf STDERR "OK\n";
    }
}

sub _add_job {
    my ($self, $worker, $file, %opts) = @_;

    croak "usage: $0 add_job <worker> <file>"
        unless defined($worker) && -r $file;

    my $importer = Catmandu->importer('YAML', file => $file);
    my $exporter = Catmandu->exporter('YAML');
    my $queue    = LibreCat::App::Helper::Helpers->new->queue;

    $importer->each(
        sub {
            my $job = $_[0];

            my $job_id = $queue->add_job($worker, $job);

            print "Adding job:\n";

            $exporter->add($job);

            unless ($opts{background}) {
                print "[$job_id]:";
                while (1) {
                    print "+";
                    my $job = $queue->job_status($job_id);
                    last if $job->done;
                    sleep 1;
                }
                print "DONE\n";
            }
        }
    );

    $exporter->commit;
}

sub _status {
    my $gm = Net::Telnet::Gearman->new(Host => '127.0.0.1', Port => 4730,);
    my $version = $gm->version;
    $version =~ s/^OK //;
    my $status = "Server version: $version\n";
    $status .= "Workers:\n";
    $status .= Catmandu->export_to_string(
        [
            map {
                +{
                    fd        => $_->file_descriptor,
                    ip        => $_->ip_address,
                    id        => $_->client_id,
                    functions => join(",", @{$_->functions}),
                    }
            } $gm->workers
        ],
        'Table',
        fields => 'fd,ip,id,functions',
    );
    $status .= "Status:\n";
    $status .= Catmandu->export_to_string(
        [
            map {
                +{
                    function => $_->name,
                    queued   => $_->queue,
                    busy     => $_->busy,
                    free     => $_->free,
                    running  => $_->running,
                    }
            } $gm->status
        ],
        'Table',
        fields => 'function,queued,busy,free,running',
    );
    say $status;

    return 0;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::queue - show job queue status

=head1 SYNOPSIS

    # Show the status of all worker
    librecat queue status

    # Submit a YAML file job to the WORKER
    librecat [--background] queue add_job WORKER FILE

    # Start all configured workers
    librecat queue start

    # Stop all configured workers
    librecat queue stop

=cut
