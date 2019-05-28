package LibreCat::Error::VersionConflict;

use Catmandu::Sane;
use Moo;
use namespace::clean;

extends 'LibreCat::Error';

has model            => (is => 'ro', required => 1);
has id               => (is => 'ro', required => 1);
has version          => (is => 'ro', required => 1);
has expected_version => (is => 'ro', required => 1);

sub _build_message {
    my ($self) = @_;
    my $model            = $self->model->name;
    my $id               = $self->id;
    my $version          = $self->version;
    my $expected_version = $self->expected_version;
    "$model $id: expected version $expected_version, but got version $version";
};

1;

