package LibreCat::Cmd::worker;

use Catmandu::Sane;
use Catmandu::Util qw(require_package check_maybe_hash_ref);
use Catmandu;
use Gearman::Worker;
use Parallel::ForkManager;
use POSIX;
use String::CamelCase qw(camelize);
use Log::Log4perl;
use JSON::MaybeXS;

use parent 'LibreCat::Cmd';

our $PID_FILE;
our $QUIT = 0;

sub description {
    return <<EOF;
Usage:

librecat worker <worker>

Examples:

librecat worker mailer

Options:
EOF
}

sub command_opt_spec {
    my ($class) = @_;
    (
        ['daemonize|D',    ""],
        ['workers=i',      "", {default => 1}],
        ['program-name=s', ""],
        ['pid-file=s',     ""],
        ['sleep-retry',    "", {default => 0}],
    );
}

sub default_program_name {
    my ($self, $worker_name) = @_;
    "librecat-worker-$worker_name";
}

sub _logger {
    Log::Log4perl->get_logger(__PACKAGE__);
}

sub _write_pid_file {
    my ($pid) = @_;
    open(my $fh, '>', $PID_FILE)
        || die "could not open pid file '$PID_FILE' $!";
    print $fh $pid;
    close $fh;
}

sub _fork {
    if (defined(my $pid = fork)) {
        return $pid;
    }
    die "can't fork: $!";
}

sub _open_max {
    my $open_max = POSIX::sysconf(&POSIX::_SC_OPEN_MAX);
    (!defined($open_max) || $open_max < 0) ? 64 : $open_max;
}

sub _daemonize {
    _fork && return 1;

    POSIX::setsid || die "unable to detach from controlling terminal";

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
    for (0 .. _open_max) {POSIX::close($_);}

    # reopen stderr, stdout, stdin to /dev/null
    open(STDIN,  "+>/dev/null");
    open(STDOUT, "+>&STDIN");
    open(STDERR, "+>&STDIN");

    0;
}

sub command {
    my ($self, $opts, $args) = @_;

    my $num_workers  = $opts->workers;
    my $worker_name  = camelize($args->[0]);
    my $worker_class = require_package($worker_name, 'LibreCat::Worker');
    my $program_name = $opts->program_name
        // $self->default_program_name($worker_name);
    my $gm_servers   = [{host => '127.0.0.1', port => 4730}];
    my $sleep        = $opts->sleep_retry;
    my $error_method = $sleep ? 'logwarn' : 'logdie';

    if ($opts->daemonize) {
        _logger->info("forking daemon for $worker_class");
        _daemonize && return 1;
        $0 = $program_name;
    } else {
      $SIG{INT} = sub {
          $QUIT = 1;
      };
    }

    $SIG{TERM} = sub {
        $QUIT = 1;
    };

    my @pids;

    my $pm = Parallel::ForkManager->new($num_workers);

    $pm->run_on_start(sub {my $pid = $_[0]; push @pids, $pid;});

    for (1 .. $num_workers) {
        $pm->start && next;

        my $logger = _logger;

        $logger->info("forked daemon for $worker_class");

        my $gm_worker = Gearman::Worker->new(job_servers => $gm_servers);

        my $worker
            = $worker_class->new(Catmandu->config->{worker}{$worker_name}
                || {});

        for my $func_name (@{$worker->worker_functions}) {
            my $method_name = $func_name;
            if (ref $func_name) {
                ($method_name) = values %$func_name;
                ($func_name)   = keys %$func_name;
            }

            my $func = sub {
                my ($job) = @_;
                $worker->$method_name(decode_json($job->workload), $job);
                return;
            };

            $gm_worker->register_function($func_name, 0, $func, {}) //
                $logger->logdie(
                    "failed to register function ($func_name) for worker $program_name:"
                        . $gm_worker->error);
        }

        $logger->info("starting $program_name");
        $gm_worker->work(
            # TODO add other callbacks
            stop_if => sub { $QUIT },
        );
        $logger->info("exiting $program_name");
        $pm->finish;
    }

    $pm->wait_all_children;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::worker - start librecat worker daemons

=head1 SYNOPSIS

    librecat worker mailer

=cut
