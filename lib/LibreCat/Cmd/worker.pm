package LibreCat::Cmd::worker;

use Catmandu::Sane;
use Catmandu::Util qw(require_package);
use Gearman::Worker;
use Parallel::ForkManager;
use POSIX;
use String::CamelCase qw(camelize);
use Log::Log4perl;
use JSON::MaybeXS;
use LibreCat qw(:self);

use parent 'LibreCat::Cmd';

our $PID_FILE;

sub description {
    return <<EOF;
Usage:

librecat worker [options]

Examples:

librecat worker start
librecat worker start -D --pid-file /var/run/librecat-worker.pid

Options:
EOF
}

sub command_opt_spec {
    my ($class) = @_;
    (
        ['daemonize|D',    ""],
        ['pid-file=s',     ""],
    );
}

sub _logger {
    Log::Log4perl->get_logger(__PACKAGE__);
}

sub _write_pid_file {
    my ($pid) = @_;
    open(my $fh, '>', $PID_FILE)
        || _logger->logdie("could not open pid file '$PID_FILE' $!");
    print $fh $pid;
    close $fh;
}

sub _fork {
    if (defined(my $pid = fork)) {
        return $pid;
    }
    _logger->logdie("can't fork: $!");
}

sub _max_open_files {
    my $max = POSIX::sysconf(&POSIX::_SC_OPEN_MAX);
    (!defined($max) || $max < 0) ? 64 : $max;
}

sub _daemonize {
    _fork && return 1;

    _logger->logdie("unable to detach from controlling terminal")
        if POSIX::setsid() < 0;

    $SIG{HUP} = 'IGNORE';

    if (my $pid = _fork) {
        _write_pid_file($pid) if defined $PID_FILE;
        exit 0;
    }

    # change working directory
    chdir '/';

    # clear file creation mask
    umask 0;

    # close open file descriptors
    for (0 .. _max_open_files) { POSIX::close($_) }

    # reopen stderr, stdout, stdin to /dev/null
    open(STDIN,  "+>/dev/null");
    open(STDOUT, "+>&STDIN");
    open(STDERR, "+>&STDIN");

    0;
}

sub _start {
    my ($self, $opts, $args) = @_;

    my $program_name = 'librecat-worker';
    my $gm_servers = librecat->config->{queue}{servers} //
        [{host => '127.0.0.1', port => 4730}];
    my $worker_config = librecat->config->{queue}{workers} //
        _logger->logdie("no queue.workers configured");

    # fork the controlling daemon
    if ($opts->daemonize) {
        _logger->info("forking $program_name daemon");
        $PID_FILE = $opts->pid_file;
        _daemonize && return 1;
        $0 = $program_name;
    }

    my @worker_specs;

    for my $worker_name (keys %$worker_config) {
        my $spec = $worker_config->{$worker_name};
        my $n = $spec->{count} // 1;
        my $package = $spec->{package} // camelize($worker_name);
        my $options = $spec->{options} // {};
        for (my $i = 0; $i < $n; $i++) {
            push @worker_specs, {
                program_name => join('-', $program_name, $worker_name, $i+1),
                package      => $package,
                options      => $options,
            };
        }
    }

    my $pm = Parallel::ForkManager->new(scalar @worker_specs);
    my @pids;

    $SIG{INT} = $SIG{TERM} = sub { kill 'TERM', @pids; };

    $pm->run_on_start(sub { my $pid = $_[0]; push @pids, $pid; });

    # fork the workers
    for my $spec (@worker_specs) {
        $pm->start && next;

        $0 = $spec->{program_name};

        my $logger = _logger;

        $logger->info("forked $0");

        my $gm_worker    = Gearman::Worker->new(job_servers => $gm_servers);
        my $worker_class = require_package($spec->{package}, 'LibreCat::Worker');
        my $worker       = $worker_class->new($spec->{options});

        for my $func_name (@{$worker->worker_functions}) {
            my $method_name = $func_name;
            if (ref $func_name) {
                ($method_name) = values %$func_name;
                ($func_name)   = keys %$func_name;
            }

            my $func = sub {
                my ($job) = @_;
                $worker->$method_name(decode_json($job->arg), $job);
                return;
            };

            $gm_worker->register_function($func_name, 0, $func, {}) //
                $logger->logdie(
                    "failed to register function ($func_name) for worker $worker_class:"
                        . $gm_worker->error);
        }

        my $quit = 0;
        $SIG{INT} = $SIG{TERM} = sub { $quit = 1; };

        $logger->info("started $0");
        $gm_worker->work(
            # TODO add other callbacks
            stop_if => sub { $quit },
        );
        $logger->info("stopped $0");
        $pm->finish;
    }

    $pm->wait_all_children;
}

sub command {
    my ($self, $opts, $args) = @_;

    my $commands = qr/start/;

    my $cmd = shift @$args;

    unless ($cmd && $cmd =~ /^$commands$/) {
        $self->usage_error("should be one of $commands");
    }

    if ($cmd eq 'start') {
        $self->_start($opts, $args);
    }
}

1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::worker - start librecat worker daemons

=head1 SYNOPSIS

    # with a config/queue.yml like this:
    queue:
      workers:
        mailer:
          count: 2

    # start worker processes:
    librecat worker start
    # this foreground process will control 2 worker processes:
    # librecat-worker-mailer-1
    # librecat-worker-mailer-2

    # stopping this process with ctrl-c or kill -s TERM <pid> will also gracefully
    # stop the workers

    # the daemonized version
    librecat worker start -D --pid-file /var/run/librecat-worker.pid
    # will start 3 processes and then exit:
    # librecat-worker (the controlling daemon)
    # librecat-worker-mailer-1
    # librecat-worker-mailer-2

    # stopping the daemonized version
    kill -s TERM `cat /var/run/librecat-worker.pid`

=cut
