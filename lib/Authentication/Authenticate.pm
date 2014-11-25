package Authentication::Authenticate;

use App::Helper;
use Authentication::LDAP;
use Authentication::LDAP::UNIBI;
use base 'Exporter';
use strict;

our @EXPORT = qw(verifyUser withAuthentication);

sub verifyUser {
    my ($username, $password) = @_;

    if (!$username or !$password) {
        return "error";
    }

    withAuthentication($username, $password);
    #withAuthentication(sub {
    #    my $auth = shift; $auth->verify($auth, $username, $password);
    #});
}

sub withAuthentication {
    #my $self       = shift;
    my $username = shift;
    my $password = shift;
    #my $authAction = shift;
    my $authResult;

    my $cfg = h->config->{authentication};
    my $authClass = $cfg->{class};
    my $authParam = $cfg->{param};

    my $auth = $authClass->new(
        param        => $authParam,
        debugHandler => sub { my $text = shift; },
        errorHandler => sub { my $text = shift; },
    );

    if ($auth->onEnter) {
    	$authResult = $auth->verify($username, $password);
    	$auth->onLeave;
    }

    $authResult;
}

1;
