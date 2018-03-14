package LibreCat::Model;

use Catmandu::Sane;
use Moo::Role;
use Catmandu::Util qw(require_package);
use namespace::clean;

with 'LibreCat::Logger';

has bag        => (is => 'ro', required => 1);
has search_bag => (is => 'ro', required => 1);
has validator  => (is => 'lazy');

sub _build_validator {
    my ($self) = @_;

    require_package(ucfirst($self->bag), 'LibreCat::Validator')->new;
}

sub generate_id {
    my ($self) = @_;

    $self->bag->generate_id;
}

sub get {
    my ($self, $id) = @_;

    $self->bag->get($id);
}

sub _add {
    my ($self, $rec) = @_;

    $self->bag->add($rec);
    $self->_index($rec);
}

sub _index {
    my ($self, $rec) = @_;

    $self->search_bag->add($rec);
    $self->search_bag->commit;

    # $rec;
}

sub _purge {
    my ($self, $id) = @_;

    $self->bag->delete($id);
    $self->bag->commit;

    $self->search_bag->delete($id);
    $self->search_bag->commit;

    return +{};
}

sub _validate {
    my ($self, $rec) = @_;

    my $can_store = 1;

    my $validator     = $self->validator;
    my $validator_pkg = ref $validator;

    my @white_list = $validator->white_list;

    $self->log->fatal("no white_list found for $validator_pkg ??!")
        unless @white_list;

    for my $key (keys %$rec) {
        unless (grep(/^$key$/, @white_list)) {
            $self->log->debug("deleting invalid key: $key");
            delete $rec->{$key};
        }
    }

    unless ($validator->is_valid($rec)) {
        $can_store = 0;

        # $opts{validation_error}->($validator, $rec)
        #     if $opts{validation_error}
        #     && ref($opts{validation_error}) eq 'CODE';
    }
}

1;
