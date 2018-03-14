package LibreCat::Model::User;

use Catmandu::Sane;
use Catmandu;
use Moo;
use LibreCat::Validator::User;
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

sub add {
    my ($self, $id) = @_;

}

sub delete {
    my ($self, $id) = @_;

    return {deleted => $id};
}

1;
