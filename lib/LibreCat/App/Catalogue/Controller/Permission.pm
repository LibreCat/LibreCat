package LibreCat::App::Catalogue::Controller::Permission::Permissions;

use Catmandu::Sane;
use Catmandu;
use Catmandu::Util qw(:is);
use LibreCat qw(publication);
use LibreCat::App::Helper;
use LibreCat::Access;
use Carp;
use Dancer qw(:syntax);
use Exporter qw/import/;

use Moo;

sub cache {
    var("cache") or
    var cache => +{};
}

sub cache_get {

    my($self, $key) = @_;
    my $cache   = $self->cache();
    exists($cache->{$key}) ? $cache->{$key} : undef;

}

sub cache_set {

    my($self, $key, $val) = @_;
    my $cache = cache();
    $cache->{$key} = $val;

}

sub get_cached_publication {
    my($self, $id) = @_;

    my $pub = $self->cache_get( "PUBLICATION_${id}" );
    my $set_cache = !$pub;
    $pub //= h->publication->get($id);

    $self->cache_set( "PUBLICATION_${id}", $pub) if $set_cache;

    $pub;
}

sub get_cached_user {
    my($self, $user_id) = @_;

    my $user = $self->cache_get( "USER_${user_id}" );
    my $set_cache = !$user;
    $user //= h->get_person( $user_id );

    $self->cache_set("USER_${user_id}", $user) if $set_cache;

    $user;
}

sub _can_do_action {
    my ($self, $action, $id, $opts) = @_;

    unless (defined($action)) {
        h->log->fatal("whoops! an action role needs to be filled in");
        return 0;
    }

    is_string($id)     or return 0;
    is_hash_ref($opts) or return 0;

    h->log->debug("id: $id ; opts:" . to_dumper($opts));

    my $user_id = $opts->{user_id};
    my $role    = $opts->{role};

    return 0 unless defined($user_id) && defined($role);

    my $pub = $self->get_cached_publication($id);

    is_hash_ref($pub) or return 0;

    my $user  = $self->get_cached_user($user_id);

    # do not touch deleted records
    return 0 if $pub->{status} && $pub->{status} eq 'deleted';

    #no restrictions for super_admin
    return 1 if $role eq "super_admin";

    my $action_permissions = h->config->{permissions}->{access}->{$action};

    my $action_access = LibreCat::Access->new(
        allowed_user_id   => $action_permissions->{by_user_id}   ,
        allowed_user_role => $action_permissions->{by_user_role} ,
        publication_allow => $action_permissions->{publication_allow} ,
        publication_deny  => $action_permissions->{publication_deny} ,
    );

    if ($action_access->by_user_id($pub,$user)) {
        return 1;
    }
    elsif ($action_access->by_user_role($pub,$user,$role)) {
        return 1;
    }
    else {
        return 0;
    }
}

=head2 can_edit( $self, $id, $param)

=over 4

=item id

Publication identifier

=item opts

 * user_id
 * role

=back

=cut

sub can_edit {
    my ($self, $id, $param) = @_;
    return $self->_can_do_action('can_edit', $id, $param);
}

=head2 can_delete( $self, $id, $param )

=over 4

=item id

Publication identifier

=item opts

* user_id
* role

=back

=cut

sub can_delete {
    my ($self, $id, $param) = @_;
    return $self->_can_do_action('can_delete', $id, $param);
}

=head2 can_make_public( $self, $id, $param )

=over 4

=item id

Publication identifier

=item opts

* user_id
* role

=back

=cut

sub can_make_public {
    my ($self, $id, $param) = @_;
    return $self->_can_do_action('can_make_public', $id, $param);
}

=head2 can_return( $self, $id, $param )

=over 4

=item id

Publication identifier

=item opts

* user_id
* role

=back

=cut

sub can_return {
    my ($self, $id, $param) = @_;
    return $self->_can_do_action('can_return', $id, $param);
}

=head2 can_return( $self, $id, $param )

=over 4

=item id

Publication identifier

=item opts

* user_id
* role

=back

=cut

sub can_submit {
    my ($self, $id, $param) = @_;
    return $self->_can_do_action('can_submit', $id, $param);
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

    my $pub   = $self->get_cached_publication($id);

    is_hash_ref($pub) or return (0,"");

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

    if ($pub->{status} eq 'public' && $access eq 'open_access') {
        return (1, $file_name);
    }
    elsif ($pub->{status} eq 'public' && $access eq 'local' && h->within_ip_range($ip, $ip_range)) {
        return (1, $file_name);
    }
    else {
        # closed documents can be downloaded by user
        # if and only if the user can edit the record
        my $can_download
            = $self->_can_do_action('can_edit',$id, {user_id => $user_id, role => $role});
        return ($can_download ? 1 : 0, $file_name);
    }

    return (0, '');
}

=head2 all_author_types

Returns a listing of all the user_id fields for any of the edit,delete,..actions

=cut
sub all_author_types {
    my ($self) = @_;

    my $permissions = h->config->{permissions}->{access} // {};

    my $perm_by_user_identity = {};

    for my $action (keys %$permissions) {
        my $action_perm = $permissions->{$action}->{by_user_id} // [];
        for (@$action_perm) {
            $perm_by_user_identity->{$_} = 1;
        }
    }

    return [ keys %$perm_by_user_identity ];
}


=head2 all_author_roles

Returns a listing of all the user_role fields for any of the edit,delete,..actions

=cut
sub all_author_roles {
    my ($self) = @_;

    my $permissions = h->config->{permissions}->{access} // {};

    my $perm_by_user_role = {};

    for my $action (keys %$permissions) {
        my $action_perm = $permissions->{$action}->{by_user_role} // [];
        for (@$action_perm) {
            $perm_by_user_role->{$_} = 1;
        }
    }

    return [ keys %$perm_by_user_role ];
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
