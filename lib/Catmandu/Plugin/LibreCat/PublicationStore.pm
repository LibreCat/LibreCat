package Catmandu::Plugin::LibreCat::PublicationStore;

use Catmandu::Sane;
use Catmandu::Util qw(check_string);
use Carp;
use LibreCat;
use LibreCat::App::Helper;
use LibreCat::App::Catalogue::Controller::File;
use LibreCat::App::Catalogue::Controller::Material;
use Moo::Role;
use MooX::Aliases;
use namespace::clean;

around add => sub {
    my ($orig, $self, $data) = @_;

    $self->log->info("updating " . $self->name);

    if ($self->log->is_debug) {
        $self->log->debug("add " . $data->{_id});
    }

    LibreCat::App::Catalogue::Controller::File::handle_file($data);

    if ($data->{related_material}) {
        LibreCat::App::Catalogue::Controller::Material::update_related_material(
            $data);
    }

    # Set for every update the user-id of the last editor
    unless ($data->{user_id}) {

        # Edit by a user via the command line?
        my $super_id
            = h->config->{store}->{builtin_users}->{options}->{init_data}
            ->[0]->{_id} // 'undef';
        $data->{user_id} = $super_id;
    }

    (!defined $data->{_validation_errors})
        ? $orig->($self, $data)
        : return $data;
};

sub set_delete_status {
    my ($self, $id) = @_;

    my $del = $self->get($id);

    if ($del->{status} eq 'public') {
        $del->{oai_deleted} = 1;
        $del->{locked}      = 1;
    }

    $del->{status} = 'deleted';
    $self->add($del);
}

sub purge {
    my ($self, $id) = @_;

    $self->delete($id);
}

1;
