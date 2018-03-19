package LibreCat::Model;

use Catmandu::Sane;
use Moo::Role;
use namespace::clean;

with 'LibreCat::Logger';

has bag        => (is => 'ro', required => 1, handles => [qw(generate_id)]);
has search_bag => (is => 'ro', required => 1);
has validator  => (is => 'ro', required => 1, handles => [qw(is_valid)]);

sub get {
    my ($self, $id) = @_;

    $self->bag->get($id);
}

sub add {
    my ($self, $rec) = @_;

    $rec = $self->prepare($rec);

    if ($self->is_valid($rec)) {
        $self->_store($rec);
        $self->_index($rec);
    }

    $rec;
}

sub delete {
    my ($self, $id) = @_;
    return unless $self->get($id);
    $self->_purge($id);
}

sub _store {
    my ($self, $rec) = @_;

    $rec = $self->bag->add($rec);
    $rec = $self->_index($rec);

    $rec;
}

sub _index {
    my ($self, $rec) = @_;

    $rec = $self->search_bag->add($rec);
    $self->search_bag->commit;

    $rec;
}

sub _purge {
    my ($self, $id) = @_;

    $self->bag->delete($id);
    $self->bag->commit;

    $self->search_bag->delete($id);
    $self->search_bag->commit;

    $id;
}

sub prepare {
    my ($self, $rec) = @_;
    $self->_apply_whitelist($rec);
    $rec;
}

sub _apply_whitelist {
    my ($self, $rec) = @_;
    my $validator = $self->validator;
    my $whitelist = $validator->whitelist;
    for my $key (keys %$rec) {
        unless (grep { $_ eq $key } @$whitelist) {
            $self->log->debug("deleting invalid key: $key");
            delete $rec->{$key};
        }
    }
    $rec;
}

1;
