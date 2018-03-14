package LibreCat::Model::User;

use Catmandu::Sane;
use Catmandu;
use Moo;
use namespace::clean;

extends 'LibreCat::User';
with 'LibreCat::Model';

sub add {
    my ($self, $rec) = @_;


    my $saved_record = $self->add($rec);
    $self->$bagname->commit;
    return $saved_record;
}

sub delete {
    my ($self, $id) = @_;

    $self->_purge($id);
}

1;
