package LibreCat::Queue;

use Catmandu::Sane;
use Gearman::XS qw(:constants);
use Gearman::XS::Client;
use Moo;

has gearman => (is => 'lazy');

sub _build_gearman {
    my $client = Gearman::XS::Client->new;
    $client->add_server('127.0.0.1', 4730);
    $client;
}

sub add_job {
    my ($self, @args) = @_;
    my ($ret, $job_handle) = $self->gearman->do_background(@args);
    if ($ret != GEARMAN_SUCCESS) {
        Catmandu::Error->throw($self->gearman->error);
    }
    $job_handle;
}

1;

