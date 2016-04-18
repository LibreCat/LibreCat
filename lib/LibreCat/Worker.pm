package LibreCat::Worker;

use Catmandu::Sane;
use Gearman::XS::Worker;
use JSON::MaybeXS;

use parent 'LibreCat::Daemon';

sub daemon {
    my ($self) = @_;
    sub {
        my $worker = Gearman::XS::Worker->new;
        $worker->add_server('127.0.0.1', 4730);
        for ($self->function_spec) {
            my @spec = @$_;
            my $func = $spec[2];
            $spec[2] = sub {
                my ($job) = @_;
                my $workload = decode_json($job->workload);
                my $res = $func->($job, $workload);
                encode_json($res);
            };
            $worker->add_function(@spec);
        }
        $worker->work while 1;
    };
}

1;

__END__

=pod

=head1 NAME

LibreCat::Worker - a base class for worker daemons

=head1 SYNOPSIS

    package LibreCat::Cmd::drunkard;

    use Catmandu::Sane;

    use parent 'LibreCat::Worker';

    sub function_spec {
        my ($self) = @_;
        (
            ['drink_beer', 0, \&do_drink_beer, {}],
            ['drink_wine', 0, \&do_drink_wine, {}],
        );
    }

    sub do_drink_beer {
        say STDERR 'drinking a beer ...';
        sleep 5;
    }

    sub do_drink_wine {
        say STDERR 'drinking a glass of wine ...';
        sleep 5;
    }

=cut
