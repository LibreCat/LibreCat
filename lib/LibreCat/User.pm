package LibreCat::User;

use Catmandu::Sane;
use Catmandu;
use Moo;
use namespace::clean;

has sources => (is => 'ro', default => sub {[]},);

has username_attr => (is => 'ro', default => sub {'username'},);

has _bags => (is => 'lazy', builder => '_build_bags',);

has _username_attrs => (is => 'lazy', builder => '_build_username_attrs',);

with 'Catmandu::Logger';

sub _build_username_attrs {
    my ($self) = @_;
    [map {$_->{username_attr} // $self->username_attr;} @{$self->sources}];
}

sub _build_bags {
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

sub find_by_username {
    my ($self, $username) = @_;

    $self->log->debug("find_by_username($username)");

    my $bags  = $self->_bags;
    my $attrs = $self->_username_attrs;

    for (my $i = 0; $i < @$bags; $i++) {
        my $bag = $bags->[$i];
        $self->log->debug("..probing $bag");

        if ($bag->does('Catmandu::Searchable')) {

 # For now we assume the Searchable store are ElasticSearch implementations...
            my $query = sprintf "%s:%s", $attrs->[$i], $username;

            $self->log->debug("..query $query");

            my $hits = $bag->search(query => $query);

            if (my $user = $hits->first) {
                $self->log->debug("..found $user");
                return $user;
            }
        }
        elsif (my $user = $bags->[$i]->detect($attrs->[$i] => $username)) {
            $self->log->debug("..found $user");
            return $user;
        }
    }

    $self->log->debug("..no results");

    return;
}

sub to_session {

    my ( $self, $user ) = @_;

    my $super_admin      = "super_admin" if $user->{super_admin};
    my $reviewer         = "reviewer" if $user->{reviewer};
    my $project_reviewer = "project_reviewer"
        if $user->{project_reviewer};
    my $data_manager     = "data_manager" if $user->{data_manager};
    my $delegate         = "delegate" if $user->{delegate};

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
