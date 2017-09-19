package LibreCat::Auth::Bag;

use Catmandu::Sane;
use Catmandu;
use App::bmkpasswd qw(passwdcmp mkpasswd);
use Moo;
use namespace::clean;

with 'LibreCat::Auth';

has store         => (is => 'ro');
has bag           => (is => 'ro');
has username_attr => (is => 'ro', default => sub {'username'});
has password_attr => (is => 'ro', default => sub {'password'});

sub _authenticate {
    my ($self, $params) = @_;
    my $username = $params->{username} // return 0;
    my $password = $params->{password} // return 0;

    my $store_name    = $self->store;
    my $store         = Catmandu->store($store_name);
    my $bag_name      = $self->bag // $store->default_bag;
    my $bag           = $store->bag($bag_name);
    my $username_attr = $self->username_attr;
    my $password_attr = $self->password_attr;

    $self->log->debugf("authenticating: %s", $username);

    $self->log->debugf("store: %s bag: %s $username_attr = $username",
        $store_name, $bag_name);

    my $user;

    if ($bag->does('Catmandu::Searchable')) {

 # For now we assume the Searchable store are ElasticSearch implementations...
        my $query = sprintf "%s:%s", $username_attr, $username;

        $self->log->debug("..query $query");
        $user = $bag->search(query => $query)->first;
    }
    else {
        $self->log->debug("..scanning for $username_attr => $username");
        $user = $bag->detect($username_attr => $username);
    }

    unless ($user) {
        $self->log->debug("$username not found");
        return undef;
    }

    # Explicitly test for inactive users ...built-in users might not
    # have all the fields set
    if ($user->{account_status} && $user->{account_status} eq 'inactive') {
        $self->log->debug("$username isn't active");
        return undef;
    }
    else {
        $self->log->debug("$username is active");
    }

    $self->log->debug("checking $password_attr for $username");

    if (exists $user->{$password_attr}) {
        if (passwdcmp($password, $user->{$password_attr})) {
            $self->log->debug("$username password ok :-)");
            return +{
                uid        => $username,
                package    => __PACKAGE__,
                package_id => $self->id
            };
        }
        else {
            $self->log->debug("$username password doesn't match");
            return undef;
        }
    }
    else {
        $self->log->error("no password set for $username");
        return undef;
    }
}

1;

__END__

=pod

=head1 NAME

LibreCat::Auth::Bag - A LibreCat authentication package backed by a
Catmandu::Store::Bag

=head1 SYNOPSIS

    use Catmandu;
    use LibreCat::Auth::Bag;

    Catmandu->config->{store}{users} = {
        package => Hash,
        options => {
            init_data => {
                login => 'demo'
                password => 's3cret',
            },
        },
    };

    my $auth = LibreCat::Auth::Bag->new(
        store => 'users',
        username_param => 'login',
    );

    if ($auth->authenticate({username => 'demo',
            password => 's3cret')) {
        say "logged in";
    }
    else {
        say "error";
    }

=head1 CONFIG

=head2 store

Name of the store in the Catmandu config. Default is the Catmandu default
store.

=head2 bag

Name of the bag. Default is the store's default bag.

=head2 username_attr

Name of the attribute containing the username. Default is 'username'.

=head2 password_attr

Name of the attribute containing the password. Default is 'password'.

=head1 SEE ALSO

L<LibreCat::Auth>

=cut
