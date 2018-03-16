package LibreCat::Model;

use Catmandu::Sane;
use Moo::Role;
use Catmandu::Util qw(require_package);
use namespace::clean;

with 'LibreCat::Logger';

has bag        => (is => 'ro', required => 1, handles => [qw(generate_id)]);
has search_bag => (is => 'ro', required => 1);
has validator_package => (is => 'lazy');
has validator  => (is => 'lazy');

sub _build_validator_package {
    my ($self) = @_;
    my $name = ref $self;
    $name =~ s/Model/Validator/;
    $name;
}

sub _build_validator {
    my ($self) = @_;

    require_package($self->validator_package)->new;
}

sub get {
    my ($self, $id) = @_;

    $self->bag->get($id);
}

sub add {
    my ($self, $rec) = @_;

    $self->_validate($rec);
    $rec = $self->_add($rec) unless $rec->{validation_error};

    $rec;
}

sub _add {
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

    # TODO should return undef if the record doesn't exist
    $id;
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
