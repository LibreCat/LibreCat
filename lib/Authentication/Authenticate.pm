package Authentication::Authenticate;

use App::Helper;
use Catmandu::Sane;
use Net::LDAP;
use base 'Exporter';
use strict;

our @EXPORT = qw(verifyUser withAuthentication);

sub verifyUser {
    my ($username, $password) = @_;

    if (!$username or !$password) {
        return "error";
    }

    withAuthentication($username, $password);
}

sub withAuthentication {
    my $username = shift;
    my $password = shift;

    my $cfg = h->config->{authentication}->{param};

    my $ldap = Net::LDAP->new( $cfg->{host} );
    my $base = sprintf($cfg->{auth_base}, $username);
    my $bind = $ldap->bind( $base, password => $password);

    $ldap->unbind;

    if ($bind->code == Net::LDAP::LDAP_SUCCESS) {
    	return 1;
    } else {
    	return 0;
    }
}

1;
