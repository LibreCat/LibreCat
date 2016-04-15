package LibreCat::Worker;

use Catmandu::Sane;
use Gearman::XS::Worker;

use parent 'LibreCat::Daemon';

sub daemon {
    my ($self) = @_;
    sub {
        my $worker = Gearman::XS::Worker->new;
        $worker->add_server('127.0.0.1', 4730);
        $worker->add_function(@$_) for $self->function_spec;
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
