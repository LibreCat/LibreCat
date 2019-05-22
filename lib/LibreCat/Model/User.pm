package LibreCat::Model::User;

use Catmandu::Sane;
use LibreCat qw(:self);
use Catmandu;
use Catmandu::Util qw(:is);
use Moo;
use namespace::clean;

with 'LibreCat::Model';

has sources       => (is => 'ro', default => sub {[]},);
has username_attr => (is => 'ro', default => sub {'username'},);
has _bags         => (is => 'lazy',);
has _username_attrs => (is => 'lazy');

sub _build__username_attrs {
    my ($self) = @_;
    [map {$_->{username_attr} // $self->username_attr;} @{$self->sources}];
}

sub _build__bags {
    my ($self) = @_;
    [
        map {
            my $store = Catmandu->store($_->{store});
            $store->bag($_->{bag} // $store->default_bag);
        } @{$self->sources}
    ];
}

sub get {
    my ($self, $id) = @_;

    $self->log->debug("get($id)");

    for my $bag (@{$self->_bags}) {

        $self->log->debug("..probing $bag");

        if (my $user = $bag->get($id)) {
            $self->log->debug("..found $user");
            return $user;
        }
    }

    $self->log->debug("..no results");

    return;
}

# TODO clean this up
sub find {
    my ($self, $id) = @_;
    if ($id) {
        my $hits = librecat->searcher->search('user', {cql => ["id=$id"]});
        $hits = librecat->searcher->search('user', {cql => ["login=$id"]})
            if !$hits->{total};
        return $hits->{hits}->[0] if $hits->{total};
        if (my $user = $self->get($id) || $self->find_by_username($id)) {
            return $user;
        }
    }
}

sub find_by_username {
    my ($self, $username) = @_;

    $self->log->debug("find_by_username($username)");

    my $bags  = $self->_bags;
    my $attrs = $self->_username_attrs;

    for (my $i = 0; $i < @$bags; $i++) {
        my $bag = $bags->[$i];
        $self->log->debug("..probing $bag");

        if ($bag->does('Catmandu::Searchable')) {

            # for now we assume the Searchable store is ElasticSearch
            my $query = sprintf "%s:%s", $attrs->[$i], $username;

            $self->log->debug("..query $query");

            my $hits = $bag->search(query => $query);

            if (my $user = $hits->first) {
                $self->log->debug("..found $user");

                if(
                    is_string( $user->{account_status} ) &&
                    $user->{account_status} eq "inactive"
                ){

                    $self->log->debug("..user $user->{_id} has account_status 'inactive'");
                    return;

                }

                return $user;
            }
        }
        elsif (my $user = $bags->[$i]->detect($attrs->[$i] => $username)) {
            $self->log->debug("..found $user");

            if(
                is_string( $user->{account_status} ) &&
                $user->{account_status} eq "inactive"
            ){

                $self->log->debug("..user $user->{_id} has account_status 'inactive'");
                return;

            }

            return $user;
        }
    }

    $self->log->debug("..no results");

    return;
}

# TODO does this belong here?
sub to_session {

    my ($self, $user) = @_;

    my $super_admin      = "super_admin"      if $user->{super_admin};
    my $reviewer         = "reviewer"         if $user->{reviewer};
    my $project_reviewer = "project_reviewer" if $user->{project_reviewer};
    my $data_manager     = "data_manager"     if $user->{data_manager};
    my $delegate         = "delegate"         if $user->{delegate};

    (
        role => $super_admin
            || $reviewer
            || $project_reviewer
            || $data_manager
            || $delegate
            || "user",
        user    => $user->{login},
        user_id => $user->{_id},
        lang    => $user->{lang} || Catmandu->config->{default_lang}
    );

}

1;

__END__

=pod

=head1 NAME

LibreCat::Model::User - a user model

=head1 SYNOPSIS

    package MyPackage;

    use LibreCat qw(user);

    my $rec = user->get(123);

    if (user->add($rec)) {
        print "OK!";
    }

    user->delete(123);

=head1 METHODS

=head2 find($id/$login)

=head2 find_by_username($name)

=head2 to_session($user)

=head1 SEE ALSO

L<LibreCat>, L<LibreCat::Model>

=cut
