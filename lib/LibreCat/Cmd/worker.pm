package LibreCat::Cmd::worker;

use Catmandu::Sane;
use Catmandu::Util qw(require_package check_maybe_hash_ref);
use Catmandu;
use Gearman::XS::Worker;
use String::CamelCase qw(camelize);
use JSON::MaybeXS;

use parent 'LibreCat::Daemon';

sub description {
    return <<EOF;
Usage:

librecat worker [options] <worker> start|stop|restart|status

Examples:

librecat worker mailer start --workers 2 --supervise
librecat worker mailer stop --workers 2 --supervise

EOF
}

sub daemon_name {
    my ($self, $opts, $args) = @_;

    unless (@$args > 1) {
        $self->usage_error("worker name missing");
    }

    my $base_name = $self->SUPER::daemon_name();
    "$base_name-$args->[0]";
}

sub daemon {
    my ($self, $opts, $args) = @_;

    unless (@$args > 1) {
        $self->usage_error("worker name missing");
    }

    my $worker_name = camelize($args->[0]);
    my $worker_class = require_package($worker_name, 'LibreCat::Worker');

    sub {
        my $gm_worker = Gearman::XS::Worker->new;
        $gm_worker->add_server('127.0.0.1', 4730);
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
            $gm_worker->add_function($func_name, 0, $func, {});
            $gm_worker->set_log_fn(
                sub {
                    $worker->log->info(@_);
                },
                1
            );
        }
        $gm_worker->work while 1;
    };
}

1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::worker - manage librecat worker processes

=head1 SYNOPSIS

    # this will start 2 LibreCat::Worker::Mailer worker processes
    # and 1 supervising process
    librecat worker mailer start --workers 2 --supervise
    # stop them again
    librecat worker mailer stop --workers 2 --supervise

=cut
