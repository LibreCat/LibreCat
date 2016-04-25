package LibreCat::Queue;

use Catmandu::Sane;
use Gearman::XS qw(:constants);
use Gearman::XS::Client;
use JSON::MaybeXS;
use Moo;
use namespace::clean;

has gearman => (is => 'lazy');

sub _build_gearman {
    my $client = Gearman::XS::Client->new;
    $client->add_server('127.0.0.1', 4730);
    $client;
}

sub add_job {
    my ($self, $func, $workload) = @_;
    my ($ret, $job_handle) =
        $self->gearman->do_background($func, encode_json($workload));
    if ($ret != GEARMAN_SUCCESS) {
        Catmandu::Error->throw($self->gearman->error);
    }
    $job_handle;
}

1;

