package LibreCat::User;

use Catmandu::Sane;
use Catmandu;
use Catmandu::Util qw(is_array_ref array_includes);
use LibreCat::Role;
use Moo;
use namespace::clean;

with 'Catmandu::Iterable';

has rule_config => (is => 'ro', default => sub {+{}}, init_arg => 'rules');
has role_config => (is => 'ro', default => sub {+{}}, init_arg => 'roles');
has sources     => (is => 'ro', default => sub {[]},);
has bags        => (is => 'lazy');
has username_attr => (is => 'ro', default => sub {'username'},);
has _username_attrs => (is => 'lazy', builder => '_build_username_attrs',);
has _roles => (is => 'ro', default => sub {+{}},);

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
    [map {is_array_ref($_) ? $_ : [split ' ', $_]} @$rules];
}

sub _get_role {
    my ($self, $name) = @_;
    my $roles = $self->_roles;
    $roles->{$name} ||= do {
        my $config = $self->role_config->{$name};
        my $rules  = $self->_get_rules($config);
        my $params = $config->{params};
        while ($config->{inherit}) {
            $config = $self->role_config->{$config->{inherit}};
            if ($config->{params}) {
                for my $param (@{$config->{params}}) {
                    if (array_includes($params, $param)) {
                        Catmandu::BadVal->throw(
                            "Can't inherit from a role that already uses param '$param'"
                        );
                    }
                    unshift @$params, $param;
                }
            }
            unshift @$rules, @{$self->_get_rules($config)};
        }
        LibreCat::Role->new(
            rule_config => $self->rule_config,
            rules       => $rules,
            params      => $params
        );
    };
}

sub generator {
    my ($self) = @_;
    sub {
        state $generators = [map {$_->generator} @$self];
        while (@$generators) {
            my $data = $generators->[0]->();
            return $data if defined $data;
            shift @$generators;
        }
        return;
    };
}

sub get {
    my ($self, $id) = @_;
    for my $bag (@{$self->bags}) {
        if (my $user = $bag->get($id)) {
            return $user;
        }
    }
    return;
}

sub get_by_username {
    my ($self, $username) = @_;
    my $bags  = $self->bags;
    my $attrs = $self->_username_attrs;
    for (my $i = 0; $i < @$bags; $i++) {
        if (my $user = $bags->[$i]->detect($attrs->[$i] => $username)) {
            return $user;
        }
    }
    return;
}

sub may {
    my ($self, $user, $verb, $data) = @_;
    for my $params (@{$user->{roles} || []}) {
        my $role = $self->_get_role($params->{role});
        if ($role->may($user, $verb, $data, $params)) {
            return 1;
        }
    }
    0;
}

sub rules {
    my ($self, $user) = @_;
    [map {@{$_->rules}} map {$self->_get_role($_)} @{$user->{roles} || []}];
}

1;

__END__

