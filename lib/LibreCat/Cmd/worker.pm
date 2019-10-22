package LibreCat::Cmd::worker;

use Catmandu::Sane;
use Catmandu::Util qw(require_package check_maybe_hash_ref);
use Catmandu;
use Gearman::XS qw(:constants);
use Gearman::XS::Worker;
use Perl::Unsafe::Signals;
use POSIX;
use String::CamelCase qw(camelize);
use Log::Log4perl;
use JSON::MaybeXS;

use parent 'LibreCat::Cmd';

our $GEARMAN_WORKER;
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
        ['program-name=s',  ""],
        ['pid-file=s',  ""],
        ['sleep-retry',  "", {default => 0}],
    );
}

sub default_program_name {
    my ($self, $worker_name) = @_;
    "librecat-worker-$worker_name";
}

sub logger {
    my ($self) = @_;
    $self->{logger} //= Log::Log4perl->get_logger(ref $self);
}

# code mostly stolen from GearmanX::Starter
sub command {
    my ($self, $opts, $args) = @_;

    if (!$args->[0]) {
        $self->usage_error("worker name missing");
    }

    my $logger          = $self->logger;
    my $worker_name     = camelize($args->[0]);
    my $worker_class    = require_package($worker_name, 'LibreCat::Worker');
    my $program_name    = $opts->program_name // $self->default_program_name($worker_name);
    my $gearman_servers = [['127.0.0.1', 4730]];
    my $sleep           = $opts->sleep_retry;
    my $error_method    = $sleep ? 'logwarn' : 'logdie';

    $PID_FILE = $opts->pid_file;

    $logger->info("forking daemon for $worker_class");

    _init() && return 1;

    $SIG{TERM} = sub {
        $QUIT = 1;
    };

    $logger->info("creating worker $program_name");

    $0 = $program_name;

    $GEARMAN_WORKER = Gearman::XS::Worker->new;

    for my $server (@$gearman_servers) {
        if ($GEARMAN_WORKER->add_server(@$server) != GEARMAN_SUCCESS) {
            $logger->logdie("failed to add job server [@$server] to worker $program_name: " . $GEARMAN_WORKER->error);
        }
    }

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

        my $res = $GEARMAN_WORKER->add_function($func_name, 0, $func, {});
        if ($res != GEARMAN_SUCCESS) {
            $logger->logdie("failed to register function ($func_name) for worker $program_name:" . $GEARMAN_WORKER->error);
        }
    }

    $logger->info("starting $program_name");
    while (1) {
        my $res = eval {
            my $ret;
            UNSAFE_SIGNALS {$ret = $GEARMAN_WORKER->work};
            if ($ret != GEARMAN_SUCCESS) {
                $logger->$error_method(
                    'failed to initiate waiting for a job: ' . $GEARMAN_WORKER->error);
                sleep $sleep;
            }
            1;
        };
        if (!$res && $@ !~ /GearmanXQuitLoop/) {
            $logger->logdie("error running loop for worker $program_name [$@]:" . $GEARMAN_WORKER->error);
        }

        last if $QUIT;
    }
    $logger->info("exiting $program_name");
    exit 0;
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

sub _write_pid_file {
    my ($pid) = @_;
    open(my $fh, '>', $PID_FILE) || die "could not open pid file '$PID_FILE' $!";
    print $fh $pid;
    close $fh;
}

sub _init {
    my $sid;

    _fork() && return 1;

    die "unable to detach from controlling terminal"
      unless $sid = POSIX::setsid;

    $SIG{HUP} = 'IGNORE';

    if (my $pid = _fork()) {
        _write_pid_file($pid) if defined $PID_FILE;
        exit 0;
    }

    ## change working directory
    chdir '/';
    ## clear file creation mask
    umask 0;
    ## close open file descriptors
    for my $i (0 .. _open_max()) { POSIX::close($i); }
    ## reopen stderr, stdout, stdin to /dev/null
    open(STDIN,  "+>/dev/null");
    open(STDOUT, "+>&STDIN");
    open(STDERR, "+>&STDIN");

    0;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::worker - start librecat worker daemons

=head1 SYNOPSIS

    librecat worker mailer

=cut
