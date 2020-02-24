package LibreCat::Model::Publication;

use Catmandu::Sane;
use LibreCat qw(timestamp);
use LibreCat::App::Catalogue::Controller::File     ();
use LibreCat::App::Catalogue::Controller::Material ();
use Moo;
use namespace::clean;

with 'LibreCat::Model';

sub BUILD {
    my ($self) = @_;
    $self->prepend_before_add(
        [
            # TODO this is very dirty and executes even if validation fails
            file             => '_store_file',
            related_material => '_store_related_material',
        ]
    );
}

sub delete {
    my ($self, $id, %opts) = @_;

    my $rec = $self->get($id) || return;

    if ($rec->{oai_deleted} || $rec->{status} eq 'public') {
        $rec->{oai_deleted} = 1;
        $rec->{locked}      = 1;
    }

    $rec->{date_deleted} = timestamp;
    $rec->{status}       = 'deleted';

    # TODO can't call add because date_deleted & co aren't whitelisted
    $self->store($rec, %opts);
    $self->index($rec, %opts);

    $id;
}

sub _store_file {
    my ($self, $rec) = @_;
    LibreCat::App::Catalogue::Controller::File::handle_file($rec);
    $rec;
}

sub _store_related_material {
    my ($self, $rec) = @_;
    if ($rec->{related_material}) {
        LibreCat::App::Catalogue::Controller::Material::update_related_material(
            $rec);
    }
    $rec;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Model::Publication - a publication model

=head1 SYNOPSIS

    package MyPackage;

    use LibreCat qw(publication);

    my $rec = publication->get(123);

    if (publication->add($rec)) {
        print "OK!";
    }

    publication->delete(123);

=head1 VERSIONING

Publication records are versioned. Calling C<add> will throw
L<LibreCat::Error::VersionConflict> if the C<_version> key doesn't match the
already stored version. This is to prevent simultaneous editing. You can
disable this behavior with C<< skip_before_add => ['check_version'] >>.

=head1 SEE ALSO

L<LibreCat>, L<LibreCat::Model>, L<LibreCat::Model::Plugin::Versioning>

=cut
