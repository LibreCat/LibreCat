package LibreCat::Cmd::worker;

use Catmandu::Sane;
use Catmandu::Util qw(require_package);
use Gearman::XS::Worker;
use JSON::MaybeXS;

use parent 'LibreCat::Daemon';

sub daemon_name {
    my ($self, $opts, $args) = @_;

    unless (@$args > 1) {
        $self->usage_error("worker name missing");
    }

    my $base_name = $self->SUPER::daemon_name();
    my $fn_name = $args->[0];
    "$base_name-$fn_name";
}

sub daemon {
    my ($self, $opts, $args) = @_;

    unless (@$args > 1) {
        $self->usage_error("worker name missing");
    }

    my $fn_name = $args->[0];
    my $worker_name = $args->[0];
    # camelize name
    $worker_name =~ s/(_|\b)([a-z])/\u$2/g;
    my $worker_pkg = require_package($worker_name, 'LibreCat::Worker');

    sub {
        my $worker = $worker_pkg->new;
        my $fn = sub {
            my ($job) = @_;
            my $workload = decode_json($job->workload);
            my $res = $worker->work($workload);
            encode_json($res // {});
        };
        my $gm_worker = Gearman::XS::Worker->new;
        $gm_worker->add_server('127.0.0.1', 4730);
        $gm_worker->add_function($fn_name, 0, $fn, {});
        $gm_worker->work while 1;
    };
}

1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::worker - manage librecat worker processes

=cut
