package App::Catalogue::Controller::Permission;

use Catmandu::Sane;
use Catmandu;
use App::Helper;
use Carp;
use Exporter qw/import/;

our @EXPORT_OK = qw/can_edit can_delete can_delete_file can_download/;
our %EXPORT_TAGS = (
  can => [qw/can_edit can_delete can_delete_file can_download/],
);

sub can_edit {
    my ($id, $login, $user_role) = @_;

    my $user = h->getAccount($login)->[0];
    my $cql;
    if ($user_role eq 'super_admin') {
        return 1;
    } elsif ($user_role eq 'reviewer') {
        my @deps = map {"department=$_->{id}"} @{$user->{reviewer}};
        $cql = "(" . join(@deps, ' OR ') . ")" . " AND id=$id";
    } elsif ($user_role eq 'dataManager') {
        my @deps = map {"department=$_->{id}"} @{$user->{dataManager}};
        $cql = "(" . join(@deps, ' OR ') . ")" . " AND id=$id";
    } elsif ($user_role eq 'user') {
        $cql = "(person=$user->{_id} OR creator=$user->{_id}) AND id=$id";
        #if ($user->{delegate}) {
        #    my @delegate = map {"person=$_->{id}"} @{$user->{delegate}};
        #    $hits = h->quick_search(cql_query => "(" . join(@delegate, ' OR ') . ")" . "AND id=$id")
        #}
    }

    my $hits = h->publication->search(cql_query => $cql, limit => 1);

    ($hits->{total} == 1) ? return 1 : return 0;
}

sub can_delete {
    my ($id, $role) = @_;

    ($role eq 'super_admin') ? return 1 : return 0;
}

sub can_delete_file {
    my ($id, $user) = @_;
    return 0;
}

sub can_download {
    my ($id, $file_id, $login, $role, $ip) = @_;

    my $pub = h->publication->get($id);
    my $access;
    my $file_name;
    map {
        if ($_->{file_id} == $file_id) {
            $access = $_->{access_level};
            $file_name = $_->{file_name};
        }
    } @{$pub->{file}};

    if ($access eq 'open_access') {
        return (1, $file_name);
    } elsif ($access eq 'local' && $ip =~ /^h->{config}->{ip_range}/) {
        return (1, $file_name);
    } elsif ($access eq 'closed') {
        # closed documents can be downloaded by user
        #if and only if the user can edit the record
        return (can_edit($id, $login, $role), $file_name);
    } else {
        return (0, '');
    }

}

1;
