package LibreCat::App::Catalogue::Controller::Permission::Permissions;

use Catmandu::Sane;
use Catmandu;
use LibreCat::App::Helper;
use Dancer qw(:syntax);
use Carp;
use Exporter qw/import/;

use Moo;

sub can_edit {
    my ($self, $id, $login, $user_role) = @_;

    my $user = h->get_person($login);

    my $cql = "id=$id AND (person=$user->{_id}";

    if ($user_role eq 'super_admin') {
        return 1;
    }
    elsif ($user_role eq 'reviewer') {
        my @deps = map {"department=$_->{_id}"} @{$user->{reviewer}};
        $cql .= " OR " . join(' OR ', @deps) . ")";
    }
    elsif ($user_role eq 'project_reviewer') {
        my @projs = map {"project=$_->{_id}"} @{$user->{project_reviewer}};
        $cql .= " OR " . join(' OR ', @projs) . ")";
    }
    elsif ($user_role eq 'data_manager') {

        # not yet correct/enough!!!
        my @deps = map {"department=$_->{_id}"} @{$user->{data_manager}};
        $cql .= " OR " . join(' OR ', @deps) . ")";
    }
    elsif ($user_role eq 'delegate') {
        my @delegate = map {"person=$_"} @{$user->{delegate}};
        $cql .= " OR " . join(' OR ', @delegate) . ")";
    }
    else {
        $cql .= " OR creator=$user->{_id})";
    }
    if ($user_role ne 'super_admin') {
        $cql .= " AND locked<>1";
    }

    h->log->debug("can_edit cql: $cql");

    my $hits = h->publication->search(cql_query => $cql, limit => 1);

    ($hits->{total} == 1) ? return 1 : return 0;
}

sub can_delete {
    my ($self, $id, $role) = @_;

    ($role eq 'super_admin') ? return 1 : return 0;
}

sub can_delete_file {
    my ($self, $id, $user) = @_;
    return 0;
}

sub can_download {
    my ($self, $id, $file_id, $login, $role, $ip) = @_;

    my $ip_range = h->config->{ip_range};
    my $pub      = h->publication->get($id);
    my $access   = "";
    my $file_name;
    map {
        if ($_->{file_id} == $file_id) {
            $access    = $_->{access_level};
            $file_name = $_->{file_name};
        }
    } @{$pub->{file}};

    if ($access eq 'open_access') {
        return (1, $file_name);
    }
    elsif ($access eq 'local' && h->within_ip_range($ip,$ip_range)) {
        return (1, $file_name);
    }
    elsif ($access eq 'closed') {

        # closed documents can be downloaded by user
        #if and only if the user can edit the record
        return (0, '') unless $login;
        return ($self->can_edit($id, $login, $role), $file_name);
    }
    else {
        return (0, '');
    }
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
