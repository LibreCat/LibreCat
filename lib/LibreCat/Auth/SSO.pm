package LibreCat::Auth::SSO;

use Catmandu::Sane;
use Catmandu::Util qw(check_string);
use Carp;
use Moo::Role;
use namespace::clean;

with 'Catmandu::Logger';

has session_key => (
    is => 'ro',
    isa => sub { check_string($_[0]); },
    lazy => 1,
    default => sub { 'auth_sso' },
    required => 1
);
has authorization_url => (
    is => 'ro',
    isa => sub { check_string($_[0]); },
    lazy => 1,
    default => sub { '/' },
    required => 1
);
requires 'to_app';

#check if $env->{psgix.session} is stored Plack::Session->session
sub _check_plack_session {
    defined($_[0]->session) or die("LibreCat::Auth::SSO uses Plack::Session");
}

sub get_auth_sso {
    my ( $self, $session ) = @_;
    _check_plack_session( $session );
    $session->get( $self->session_key );
}
sub set_auth_sso {
    my ( $self, $session, $value ) = @_;
    _check_plack_session( $session );
    $session->set( $self->session_key, $value );
}

1;

=pod

=head1 NAME

LibreCat::Auth::SSO - LibreCat role for Single Sign On (SSO) authentication

=head1 SYNOPSIS

    package MySSOAuth;

    use Moo;
    use Catmandu::Util qw(:is);

    with 'LibreCat::Auth::SSO';

    sub to_app {
        my $self = shift;
        sub {
            my $env = shift;
            my $request = Plack::Request->new($env);
            my $session = Plack::Session->new($env);

            #did this app already authenticate you?
            #implementation of LibreCat::Auth::SSO should write hash to session key,
            #configured by 'session_key'
            my $auth_sso = $self->get_auth_sso($session);

            #already authenticated: what are you doing here?
            if( is_hash_ref($auth_sso)){

                return [302,[Location => $self->authorization_url],[]];

            }

            #not authenticated: do your internal work
            #..

            #everything ok: set auth_sso
            $self->set_auth_sso( $session, { type => "MySSOAuth", response => "Long response from external SSO application" }

            #redirect to other application for authorization:
            return [302,[Location => $self->authorization_url],[]];

        };
    }

    1;


    #in your app.psgi

    builder {

        mount '/auth/myssoauth' => MySSOAuth->new(

            session_key => "auth_sso",
            authorization_url => "/auth/myssoauth/callback"

        )->to_app;

        mount "/auth/myssoauth/callback" => sub {

            my $env = shift;
            my $session = Plack::Session->new($env);
            my $auth_sso = $session->get('auth_sso');

            #not authenticated yet
            unless($auth_sso){

                return [403,["Content-Type" => "text/html"],["forbidden"]];

            }

            #process auth_sso (white list, roles ..)

            [200,["Content-Type" => "text/html"],["logged in!"]];

        };

    };

=head1 DESCRIPTION

This is a Moo::Role for all Single Sign On Authentication packages. It requires
C<to_app> method, that returns a valid Plack application

An implementation is expected is to do all communication with the external
SSO application (e.g. CAS). When it succeeds, it should save the response
from the external service in the session, and redirect to the authorization
url (see below).

The authorization route must pick up the response from the session,
and log the user in.

=head1 CONFIG

=over 4

=item session_key

When authentication succeeds, the implementation saves the response
from the SSO application in this session key.

The response should look like this:

    {
        type => "<impl>",
        response => "Long response from external SSO application like CAS"
    }

This is usefull for two reasons:

    * this application can distinguish between authenticated and not authenticated users

    * the authorization application can pick up the saved response from the session

=item authorization_url

URL of the authorization route.

When authentication succeeds, this application should redirect you here

=back

=head1 METHODS

=head2 to_app

returns a Plack application

This must be implemented by subclasses

=head2 get_auth_sso($plack_session)

get saved SSO response from your session

=head2 set_auth_sso($plack_session,$hash)

save SSO response to your session

$hash should be a hash ref, and look like this:


    { type => "$type", response => "Long response from external SSO application like CAS" }

=head1 SEE ALSO

L<LibreCat::Auth::SSO::CAS>

=cut
