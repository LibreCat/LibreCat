package LibreCat::User;

use Catmandu::Sane;
use Catmandu;
use Moo;

has sources => (
    is => 'ro',
    default => sub { [] },
);

has username_attr => (
    is => 'ro',
    default => sub { 'username' },
);

has _bags => (
    is => 'lazy',
    builder => '_build_bags',
);

has _username_attrs => (
    is => 'lazy',
    builder => '_build_username_attrs',
);

sub _build_username_attrs {
    my ($self) = @_;
    [map {
        $_->{username_attr} // $self->username_attr;
    } @{$self->sources}];
}

sub _build_bags {
    my ($self) = @_;
    [map { 
        Catmandu->store($_->{store})->bag($_->{bag});
    } @{$self->sources}];
}

sub get {
    my ($self, $id) = @_;
    for my $bag (@{$self->_bags}) {
        if (my $user = $bag->get($id)) {
            return $user;
        }
    }
    return;
}

sub find_by_username {
    my ($self, $username) = @_;
    my $bags = $self->_bags;
    my $attrs = $self->_username_attrs;
    for (my $i = 0; $i < @$bags; $i++) {
        if (my $user = $bags->[$i]->detect($attrs->[$i] => $username)) {
            return $user;
        }
    }
    return;
}

1;

__END__

