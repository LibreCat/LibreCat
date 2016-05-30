package LibreCat::Daemon;

use Catmandu::Sane;
use Catmandu;
use Proc::Launcher;
use Proc::Launcher::Manager;
use File::Spec;
use Cwd ();
use namespace::clean;

use parent qw(LibreCat::Cmd);

sub command_opt_spec {
    my ($class) = @_;
    (
        ["pid-dir=s", "", {default => $class->pid_dir}],
        ["workers=i", "", {default => 1}],
        ["supervise", ""],
    );
}

sub pid_dir {
    my ($class) = @_;
    my $path = '/var/run';
    $path = Cwd::getcwd unless -d -w $path;
    $path;
}

sub command {
    my ($self, $opts, $args) = @_;

    my $commands = qr/start|stop|restart|status/;

    unless (@$args) {
        $self->usage_error("should be one of $commands");
    }

    my $cmd = $args->[-1];

    unless ($cmd =~ /^$commands$/) {
        $self->usage_error("should be one of $commands");
    }

    my $workers = $opts->workers;

    my $manager = Proc::Launcher::Manager->new(pid_dir => $opts->pid_dir);

    my $supervisor;

    my $daemon_name = $self->daemon_name($opts, $args);

    if ($opts->supervise) {
        $supervisor = $manager->supervisor(
            Proc::Launcher->new(
                daemon_name  => $daemon_name . '.supervisor',
                pid_dir      => $opts->pid_dir,
                start_method => sub {
                    Proc::Launcher::Supervisor->new(manager => $manager)
                        ->monitor;
                },
            )
        );
    }

    if ($workers > 1) {
        for (my $i = 1; $i <= $workers; $i++) {
            $manager->register(
                daemon_name  => $daemon_name . '.' . $i,
                start_method => $self->daemon($opts, $args),
            );
        }
    }
    else {
        $manager->register(
            daemon_name  => $daemon_name,
            start_method => $self->daemon($opts, $args),
        );
    }

    my $start = sub {
        if ($supervisor) {
            $supervisor->start;
            until ($supervisor->is_running) {
            }
        }
        $manager->start;
        until ($manager->is_running) {
        }
    };

    my $stop = sub {
        if ($supervisor) {
            $supervisor->stop;
            while ($supervisor->is_running) {

                # kill zombies
            }
        }
        $manager->stop;
        while ($manager->is_running) {

            # kill zombies
        }
    };

    if ($cmd eq 'start') {
        $start->();
    }
    elsif ($cmd eq 'stop') {
        $stop->();
    }
    elsif ($cmd eq 'restart') {
        $stop->();
        $start->();
    }
    elsif ($cmd eq 'status') {
        say $self->daemon_status($manager, $supervisor);
    }
}

sub daemon {
    sub {
        while (1) {sleep 1}
    };
}

sub daemon_status {
    my ($self, $manager, $supervisor) = @_;
    my @daemons = $manager->daemons;
    unshift @daemons, $supervisor if $supervisor;
    Catmandu->export_to_string(
        [
            map {
                +{
                    daemon => $_->daemon_name,
                    pid => $_->is_running ? $_->pid : "",
                    }
            } @daemons
        ],
        'Table',
        fields => 'daemon,pid',
    );
}

sub daemon_name {
    my ($self, $opts, $args) = @_;
    my $class = ref $self;
    my $name  = lc $class;
    $name =~ s/:+/-/g;
    $name;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Daemon - base class for librecat daemons

=head1 SYNOPSIS

    package LibreCat::Cmd::mydaemon;

    use parent 'LibreCat::Daemon';

    sub daemon {
        sub {
            while (1) {
                log "hard at work... ";
                sleep 5;
            }
        };

    1;

=head1 COMMAND LINE USAGE

    librecat mydaemon start --workers 10 --supervise
    librecat mydaemon stop --workers 10

=head1 SEE ALSO

L<Proc::Launcher>

=cut
