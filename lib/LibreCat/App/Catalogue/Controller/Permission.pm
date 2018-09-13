package LibreCat::App::Catalogue::Controller::Permission::Permissions;

use Catmandu::Sane;
use Catmandu;
use Catmandu::Util qw(:is);
use LibreCat::App::Helper;
use Carp;
use Dancer qw(:syntax);
use Exporter qw/import/;

use Moo;

=head2 can_edit( $self, $id, $opts )

=over 4

=item id

Publication identifier

=item opts

Hash reference containing "user_id" and "role". Both must be a string

=back

=cut

sub can_edit {
    my ($self, $id, $opts) = @_;

    my $edit_permissions = h->config->{permissions}->{access}->{can_edit};

    is_string($id)     or return 0;
    is_hash_ref($opts) or return 0;

    h->log->debug("id: $id ; opts:" . to_dumper($opts));

    my $user_id = $opts->{user_id};
    my $role    = $opts->{role};

    my $pub  = h->main_publication->get($id) or return 0;
    my $user = h->get_person($user_id)       or return 0;

    # do not touch deleted records
    return 0 if $pub->{status} && $pub->{status} eq 'deleted';

    #no restrictions for super_admin
    return 1 if $role eq "super_admin";

    #only super_admin has access to locked publications
    return 0 if $pub->{locked};

    my $perm_by_user_identity = $edit_permissions->{by_user_id} // [];
    my $perm_by_user_role     = $edit_permissions->{by_user_role} // [];

    for my $type (@$perm_by_user_identity) {
        my $identities = $pub->{$type} // [];
        $identities = [$identities] if is_hash_ref $identities;

        for my $person (@$identities) {
            # Create a virtual delegate file of all users found (we need
            # later in the subroutine...)
            push @{$pub->{delegate}} , { _id => $person->{id} };

            return 1 if $user_id eq $person->{id};
        }
    }

    my %role_permission_map = (
        reviewer         => 'department' ,
        project_reviewer => 'project' ,
        data_manager     => 'deparment' ,
        delegate         => 'delegate' ,
    );

    for my $role (@$perm_by_user_role ) {
        my $role_map = $role_permission_map{$role};

        unless ($role_map) {
            $self->log->error("no role_permission_map for $role!");
            return 0;
        }

        for my $a (@{$user->{$role} // []}) {

            $a = { _id => $a } if is_string($a);

            for my $b (@{$pub->{$role_map} // []}) {
                return 1 if $a->{_id} eq $b->{_id};
            }
        }
    }

    #cannot edit
    return 0;
}

=head2 can_delete( $self, $id, $opts )

=over 4

=item id

Publication identifier

=item opts

Hash reference containing "user_id" and "role". Both must be a string

=back

=cut

sub can_delete {
    my ($self, $id, $opts) = @_;
    return
           is_hash_ref($opts)
        && is_string($opts->{role})
        && $opts->{role} eq "super_admin" ? 1 : 0;
}

=head2 can_delete_file( $self, $id, $opts )

=over 4

=item id

Publication identifier

=item opts

Hash reference containing "user_id" and "role". Both must be a string

=back

=cut

sub can_delete_file {
    my ($self, $id, $opts) = @_;
    return 0;
}

=head2 can_download( $self, $id, $opts )

=over 4

=item id

Publication identifier

=item opts

Hash reference containing:

    * user_id (string)
    * role (string)
    * file_id (string)
    * ip (string)

=back

=cut

sub can_download {
    my ($self, $id, $opts) = @_;

    is_string($id)     or return (0, "");
    is_hash_ref($opts) or return (0, "");

    my $pub = h->main_publication->get($id) or return (0, "");

    my $file_id = $opts->{file_id};
    my $user_id = $opts->{user_id};
    my $role    = $opts->{role};
    my $ip      = $opts->{ip};

    my $ip_range = h->config->{ip_range};
    my $access;
    my $file_name;

    for (@{$pub->{file}}) {
        if ($_->{file_id} eq $file_id) {
            $access    = $_->{access_level};
            $file_name = $_->{file_name};
            last;
        }
    }

    return (0, '') unless defined $file_name;
    return (0, '') unless defined $access;

    if ($access eq 'open_access') {
        return (1, $file_name);
    }
    elsif ($access eq 'local' && h->within_ip_range($ip, $ip_range)) {
        return (1, $file_name);
    }
    elsif ($access eq 'closed') {
        # closed documents can be downloaded by user
        # if and only if the user can edit the record
        my $can_edit
            = $self->can_edit($id, {user_id => $user_id, role => $role});
        return ($can_edit ? 1 : 0, $file_name);
    }

    return (0, '');
}

package LibreCat::App::Catalogue::Controller::Permission;

my $p = LibreCat::App::Catalogue::Controller::Permission::Permissions->new;

use Catmandu::Sane;
use Dancer qw(:syntax hook);
use Dancer::Plugin;

register p => sub {$p};

hook before_template => sub {

    $_[0]->{p} = $p;

};

register_plugin;

1;
