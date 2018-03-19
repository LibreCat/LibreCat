package LibreCat::Model::User;

use Catmandu::Sane;
use Catmandu;
use Moo;
use namespace::clean;

with 'LibreCat::Model';

has sources => (is => 'ro', default => sub {[]},);
has username_attr => (is => 'ro', default => sub {'username'},);
has _bags => (is => 'lazy',);
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

1;
