package LibreCat::Auth::Bag;

use Catmandu::Sane;
use Catmandu;
use App::bmkpasswd qw(passwdcmp);
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
    my $bag      = Catmandu->store($self->store)->bag($self->bag);
    my $user = $bag->detect($self->username_attr => $username) // return 0;
    if (exists $user->{$self->password_attr}
        && passwdcmp($password, $user->{$self->password_attr}))
    {
        return 1;
    }
    0;
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
