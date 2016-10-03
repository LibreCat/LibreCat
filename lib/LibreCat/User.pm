package LibreCat::User;

use Catmandu::Sane;
use Catmandu;
use Catmandu::Util qw(is_array_ref);
use LibreCat::Role;
use Moo;
use namespace::clean;

has sources         => (is => 'ro', default => sub {[]},);
has username_attr   => (is => 'ro', default => sub {'username'},);
has _bags           => (is => 'lazy', builder => '_build_bags',);
has _username_attrs => (is => 'lazy', builder => '_build_username_attrs',);
has _roles          => (is => 'ro', default => sub {+{}},);

sub _build_username_attrs {
    my ($self) = @_;
    [map {$_->{username_attr} // $self->username_attr;} @{$self->sources}];
}

sub _build_bags {
    my ($self) = @_;
    [map {Catmandu->store($_->{store})->bag($_->{bag});} @{$self->sources}];
}

sub _get_rules {
    my ($self, $config) = @_;
    my $rules = $config->{rules} || return [];
    [map { is_array_ref($_) ? $_ : [split ' ', $_] } @$rules];
}

# TODO parametric roles
sub _get_role {
    my ($self, $name) = @_;
    my $roles = $self->_roles;
    $roles->{$name} ||= do {
        my $config = Catmandu->config->{roles}{$name};
        my $rules = $self->_get_rules($config);
        while ($config->{inherit}) {
            $config = Catmandu->config->{roles}{$config->{inherit}};
            unshift @$rules, @{$self->_get_rules($config)};
        }
        LibreCat::Role->new(
            name  => $name,
            rules => $rules,
        );
    };
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
    my $bags  = $self->_bags;
    my $attrs = $self->_username_attrs;
    for (my $i = 0; $i < @$bags; $i++) {
        if (my $user = $bags->[$i]->detect($attrs->[$i] => $username)) {
            return $user;
        }
    }
    return;
}

sub may {
    my ($self, $user, $action) = @_;
    $action = [split ' ', $action] unless is_array_ref($action);
    my $role_names = $user->{roles} || [];
    for my $name (@$role_names) {
        my $role = $self->_get_role($name);
        if ($role->may($action)) {
            return 1;
        }
    }
    0;
}

sub rules {
    my ($self, $user) = @_;
    [map { @{$_->rules} } map { $self->_get_role($_) } @{$user->{roles} || []}];
}

1;

__END__

