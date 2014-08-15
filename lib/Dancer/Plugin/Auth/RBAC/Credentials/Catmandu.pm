package Dancer::Plugin::Auth::RBAC::Credentials::Catmandu;

use Catmandu::Sane;
use Catmandu qw(store);
use Catmandu::Util qw(:is);
use Authentication::Authenticate;

use base qw/Dancer::Plugin::Auth::RBAC::Credentials/;

sub bag {
    my ( $self, $args ) = @_;
    state $bag = store( $args->{store} )->bag( $args->{bag} );
}

sub authorize {
    my ( $self, $options, @arguments ) = @_;
    my ( $login, $password ) = @arguments;

    # you are already in. return!
    my $user = $self->credentials;
    if (   is_hash_ref($user)
        && ( $user->{id} || $user->{login} )
        && !@{ $user->{error} } )
    {
        return $user;
    }

    # avoid empty phrases
    if ( !( is_string($login) && is_string($password) ) ) {
        $self->errors('login and password are required');
        return;
    }

    my $user_db = $self->bag($options)->select( "login", $login );
    # is account active?
    if ( $user_db->{active} ) {
        # ldap authentication
        my $account = verifyUser( $login, $password );
        if ( $account && $acount ne 'error' ) {
            return $self->credentials(
                {   id    => $user->{_id},
                    login => $user->{login},
                    roles => $user->{roles},
                    error => [],
                }
            );
        }
        else {
            $self->errors('login and/or password is invalid');
            return 0;
        }
    }
    else {
        $self->errors('account is not active, please contact ....');
        return 0;
    }

}

1;
