package LibreCat::Cmd::worker;

use Catmandu::Sane;
use Catmandu::Util qw(require_package check_maybe_hash_ref);
use Catmandu;
use GearmanX::Starter;
use String::CamelCase qw(camelize);
use Log::Log4perl;
use JSON::MaybeXS;

use parent 'LibreCat::Cmd';

sub description {
    return <<EOF;
Usage:

librecat worker <worker>

Examples:

librecat worker mailer

Options:
EOF
}

sub program_name {
    my ($self, $worker_name) = @_;
    "librecat-worker-$worker_name";
}

sub command {
    my ($self, $opts, $args) = @_;

    unless ($args->[0]) {
        $self->usage_error("worker name missing");
    }

    my $worker_name  = camelize($args->[0]);
    my $worker_class = require_package($worker_name, 'LibreCat::Worker');

    # TODO these should not be workers at all
    if ($worker_class->can('daemon') && ! $worker_class->daemon) {
        $self->usage_error("$worker_class is flagged not to be used as daemon");
    }

    my $program_name    = $self->program_name($worker_name);
    my $gearman_servers = [['127.0.0.1', 4730]]; # TODO make configurable
    my $functions       = [];
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

        push @$functions, [$func_name, $func];
    }

    my $gms = GearmanX::Starter->new;
    $gms->start({
        name       => $program_name,
        servers    => $gearman_servers,
        func_list  => $functions,
        dereg_func => 'unregister:%PID%',
        logger     => Log::Log4perl->get_logger(ref $self),
    });
}

1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::worker - start librecat worker daemons

=head1 SYNOPSIS

    librecat worker mailer

=cut
