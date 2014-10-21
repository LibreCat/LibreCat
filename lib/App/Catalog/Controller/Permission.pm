package App::Catalog::Controller::Permission;

use Catmandu::Sane;
use Catmandu;
use Carp;
use Exporter qw/import/;

use App::Catalog::Helper;

sub can_edit {
    my ($id, $login, $role) = @_;

    my $user = h->getAccount($login);
    my $hits;
    if ($user_role eq 'admin') {
        return 1;
    } elsif ($user_role eq 'reviewer') {
        my @deps = map {"department=$_->{id}"} @{$user->{reviewer}};
        $hits = h->quick_search(cql_query => "(" . join(@deps, ' OR ') . ")" . " AND id=$id");
    } elsif ($user_role eq 'user') {
        $hits = h->quick_search(cql_query => "(person=$user->{_id} OR creator=$user->{_id}) AND id=$id");

        if ($user->{delegate}) {
            my @delegate = map {"person=$_->{id}"} @{$user->{delegate}};
            $hits = h->quick_search(cql_query => "(" . join(@delegate, ' OR ') . ")" . "AND id=$id")
        }
    }

    $hits ? return 1 : return 0;
}

sub can_delete {
    my ($id, $role) = @_;

    ($role eq 'admin') ? return 1 : return 0;
}

sub can_delete_file {
    my ($id, $user) = @_;
}

sub can_download {
    my ($id, $file_id, $login, $role, $ip) = @_;

    my $pub = h->publication->get($id);
    my $access;
   map {
        if ($_->{id} == $file_id) {
            $access = $_->{access_level};
        }
    } @{$pub->{file}};

    if ($access eq 'oa') {
        return 1;
    } elsif ($access eq 'local' && $ip =~ /^h->{config}->{ip_range}/) {
        return 1;
    } elsif ($access eq 'closed') {
        # closed documents can be downloaded by user if user
        # can edit the record
        return can_edit($id, $login, $role);
    } else {
        return 0;
    }

}

1;
