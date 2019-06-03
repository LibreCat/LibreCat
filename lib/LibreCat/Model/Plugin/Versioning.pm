package LibreCat::Model::Plugin::Versioning;

use Catmandu::Sane;
use LibreCat::Error::VersionConflict;
use Moo::Role;

sub get_history              {shift->bag->get_history(@_)}
sub get_version              {shift->bag->get_version(@_)}
sub restore_version          {shift->bag->restore_version(@_)}
sub get_previous_version     {shift->bag->get_previous_version(@_)}
sub restore_previous_version {shift->bag->restore_previous_version(@_)}

sub BUILD {
    my ($self) = @_;
    $self->prepend_before_add(
        [
            check_version => '_check_version',
        ]
    );
}

sub _check_version {
    my ($self, $rec) = @_;
    $rec->{_version} // return $rec;
    my $prev_rec = $self->get($rec->{_id} // return $rec) // return $rec;

    if ($rec->{_version} ne $prev_rec->{_version}) {
        LibreCat::Error::VersionConflict->throw(
            model            => $self,
            id               => $rec->{_id},
            version          => $rec->{_version},
            expected_version => $prev_rec->{_version},
        );
    }

    $rec;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Model::Plugin::Versioning - a versioning plugin for models

=head1 METHODS

This plugin will add the following methods to your model:

=head2 get_history($id)

=head2 get_version($id, $version)

=head2 get_previous_version($id)

=head2 restore_version($id, $version)

=head2 restore_previous_version($id)

=head1 HOOKS

This plugin will add the following methods to your model:

=head2 before_add

=over

=item *

C<check_version>: L<LibreCat::Model> for documentation about version
conflict checking.

=back

=head1 SEE ALSO

L<LibreCat>, L<Catmandu::Plugin::Versioning>

=cut
