package LibreCat::Error::RecordNotFound;

use Catmandu::Sane;
use Moo;
use namespace::clean;

extends "LibreCat::Error";

has model            => (is => "ro", required => 1);
has id               => (is => "ro", required => 1);

sub _build_message {
    my ($self) = @_;
    my $model            = $self->model->name;
    my $id               = $self->id;
    "record $id not found in model $model";
};

1;

