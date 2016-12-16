package LibreCat::User;

use Catmandu::Sane;
use Catmandu;
use Catmandu::Util qw(is_array_ref array_includes);
use LibreCat::Role;
use Moo;
use namespace::clean;

with 'Catmandu::Iterable';

has role_config => (is => 'ro', default => sub {+{}}, init_arg => 'roles');
has sources     => (is => 'ro', default => sub {[]},);
has bags        => (is => 'lazy');
has username_attr => (is => 'ro', default => sub {'username'},);
has _username_attrs => (is => 'lazy', builder => '_build_username_attrs',);
has _roles => (is => 'ro', default => sub {+{}},);

with 'Catmandu::Logger';

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
    [map {is_array_ref($_) ? [@$_] : [split ' ', $_]} @$rules];
}

sub _get_role {
    my ($self, $name) = @_;
    my $roles = $self->_roles;
    $roles->{$name} ||= do {
        my $config = $self->role_config->{$name};
        my $rules  = $self->_get_rules($config);
        while ($config->{inherit}) {
            $config = $self->role_config->{$config->{inherit}};
            unshift @$rules, @{$self->_get_rules($config)};
        }
        LibreCat::Role->new(rules => $rules);
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

    $self->log->debug("get($id)");

    for my $bag (@{$self->bags}) {
        $self->log->debug("..probing $bag");
        if (my $user = $bag->get($id)) {
            $self->log->debug("..found $user");
            return $user;
        }
    }

    $self->log->debug("..no results");

    return;
}

sub get_by_username {
    my ($self, $username) = @_;

    $self->log->debug("find_by_username($username)");

    my $bags  = $self->bags;
    my $attrs = $self->_username_attrs;

    for (my $i = 0; $i < @$bags; $i++) {
        my $bag = $bags->[$i];
        $self->log->debug("..probing $bag");

        if ($bag->does('Catmandu::Searchable')) {
            # For now we assume the Searchable store are ElasticSearch implementations...
            my $query = sprintf "%s:%s" , $attrs->[$i] , $username;

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

sub rules_for {
    my ($self, $user) = @_;
    [map {
            my $role = $_;
            my $role_engine = $self->_get_role($_->{role});
            map {
                join ' ', map {
                    if (my $param = $role->{$_}) {
                        "$_:$param";
                    } else {
                        $_;
                    }
                } @$_;
            } @{$role_engine->rules};
    } @{$user->{roles} || []}];
}

1;

__END__
