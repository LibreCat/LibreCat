package LibreCat::Model::User;

use Catmandu::Sane;
use Catmandu;
use Moo;
use namespace::clean;

extends 'LibreCat::User';
with 'LibreCat::Model';

sub add {
    my ($self, $rec) = @_;

    my $valid_rec = $self->_validate($rec);
    $self->_add($valid_rec) unless $valid_rec->{validation_error};
}

sub delete {
    my ($self, $id) = @_;

    $self->_purge($id);
}

1;
