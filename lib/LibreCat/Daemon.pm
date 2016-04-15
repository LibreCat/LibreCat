package LibreCat::Daemon;

use Catmandu::Sane;
use Proc::Launcher;
use Proc::Launcher::Manager;
use File::Spec;
use Cwd ();

use parent qw(LibreCat::Cmd);

sub command_opt_spec {
    my ($class) = @_;
    (
        [ "daemon-name=s", "", { default => $class->daemon_name } ],
        [ "pid-dir=s", "",     { default => $class->pid_dir } ],
        [ "workers=i", "",     { default => 1 } ],
        [ "supervise", "" ],
    );
}

sub command {
    my ($self, $opts, $args) = @_;

    my $cmd = @$args ? shift @$args : 'status';

    my $workers = $opts->workers;

    my $manager = Proc::Launcher::Manager->new(pid_dir => $opts->pid_dir);

    my $supervisor;

    if ($opts->supervise) {
        $supervisor = $manager->supervisor(Proc::Launcher->new(
            daemon_name  => $opts->daemon_name.'.supervisor',
            pid_dir      => $opts->pid_dir,
            start_method => sub {
                Proc::Launcher::Supervisor->new(manager => $manager)->monitor;
            },
        ));
    }

    if ($workers > 1) {
        for (my $i = 1; $i <= $workers; $i++) {
            $manager->register(
                daemon_name  => $opts->daemon_name.'.'.$i,
                start_method => $self->daemon,
            );
        }
    } else {
        $manager->register(
            daemon_name  => $opts->daemon_name,
            start_method => $self->daemon,
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
        my @daemons = $manager->daemons;
        unshift @daemons, $supervisor if $supervisor;
        for my $daemon (@daemons) {
            my $status = $daemon->daemon_name;
            $status .= ' ('.$daemon->pid.')' if $daemon->is_running;
            say $status;
        }
    }
    else {
        $self->usage_error("should be one of start|stop|restart|status");
    }
}

sub daemon {
    sub {
        while (1) { sleep 1 }
    };
}

sub daemon_name {
    my ($class) = @_;
    my $name = lc $class;
    $name =~ s/:+/-/g;
    $name;
}

sub pid_dir {
    my ($class) = @_;
    my $path = '/var/run';
    $path = Cwd::getcwd unless -d -w $path;
    $path;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Daemon - base class for librecat daemons

=head1 SYNOPSIS

    package LibreCat::Cmd::mydaemon
    use parent 'LibreCat::Daemon';

    sub daemon {
        sub {
            while (1) {
                print "hard at work\n";
                sleep 5;
            }
        };
    }

    1;

=head1 COMMAND LINE USAGE

    catmandu mydaemon start --workers 10 --supervise
    catmandu mydaemon stop --workers 10

=head1 SEE ALSO

L<Proc::Launcher>

=cut
