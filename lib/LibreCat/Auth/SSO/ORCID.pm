package LibreCat::Auth::SSO::ORCID;

use Catmandu::Sane;
use Catmandu::Util qw(:check :is);
use Moo;
use Plack::Request;
use Plack::Session;
use LibreCat::Auth::SSO::Util qw(uri_for);
use URI;
use namespace::clean;
use LWP::UserAgent;

with 'LibreCat::Auth::SSO';

has sandbox => (
    is => 'ro',
    required => 0
);
has client_id => (
    is => 'ro',
    isa => sub { check_string($_[0]); },
    required => 1
);
has client_secret => (
    is => 'ro',
    isa => sub { check_string($_[0]); },
    required => 1
);
has _lwp => (
    is => 'ro',
    lazy => 1,
    default => sub { LWP::UserAgent->new( cookie_jar => {} ); }
);

my $base_url = "https://orcid.org";
my $sandbox_base_url = "https://sandbox.orcid.org";

sub to_app {
    my $self = $_[0];


    sub {

        my $env = $_[0];

        my $request = Plack::Request->new($env);
        my $session = Plack::Session->new( $env );
        my $params = $request->query_parameters();

        my $auth_sso = $self->get_auth_sso($session);

        #already got here before
        if ( is_hash_ref($auth_sso) ){

            return [302,[Location => $self->authorization_url],[]];

        }

        my $callback = $params->get('_callback');

        #callback phase
        if( is_string($callback) ){

            my $error = $params->get('error');
            my $error_description = $params->get('error_description');

            if(is_string($error)){

                return [500,["Content-Type" => "text/html"],[$error_description]];

            }

            my $token_url = ( $self->sandbox ? $sandbox_base_url : $base_url )."/oauth/token";

            my $res = $self->_lwp->post( $token_url,[
                client_id => $self->client_id,
                client_secret => $self->client_secret,
                grant_type => "authorization_code",
                code => $params->get('code')
            ], "Accept" => "application/json" );

            unless ( $res->is_success() ) {

                return [500,["Content-Type" => "text/html"],[ $res->content ]];

            }

            $self->set_auth_sso($session,{ package => __PACKAGE__, package_id => $self->id, response => $res->content });

            return [302,[Location => $self->authorization_url],[]];
        }
        #request phase
        else{

            my $redirect_uri = URI->new(uri_for($env,$request->script_name));
            $redirect_uri->query_form({ _callback => "true" });

            my $auth_url = URI->new(
                ( $self->sandbox ? $sandbox_base_url : $base_url )."/oauth/authorize"
            );
            $auth_url->query_form({
                show_login => 'true',
                client_id => $self->client_id,
                scope => '/authenticate',
                response_type => 'code',
                redirect_uri => $redirect_uri,
            });

            [302,[Location => $auth_url->as_string()],[]];

        }
    };
}

1;
=pod

=head1 NAME

LibreCat::Auth::SSO::ORCID - implementation of LibreCat::Auth::SSO for ORCID

=head1 SYNOPSIS

    #in your app.psgi

    builder {


        #Register THIS URI in ORCID as a new redirect_uri

        mount '/auth/orcid' => LibreCat::Auth::SSO::ORCID->new(
            client_id => "APP-1",
            client_secret => "mypassword",
            sandbox => 1,
            authorization_url => "${base_url}/auth/orcid/callback"
        )->to_app;

        #DO NOT register this uri as new redirect_uri in ORCID

        mount "/auth/orcid/callback" => sub {

            my $env = shift;
            my $session = Plack::Session->new($env);
            my $auth_sso = $session->get('auth_sso');

            #not authenticated yet
            unless($auth_sso){

                return [403,["Content-Type" => "text/html"],["forbidden"]];

            }

            #process auth_sso (white list, roles ..)

            #auth_sso is a hash reference:
            #{ type => "ORCID", response => "<response-from-orcid>" }
            #the response from orcid is in this case a json string containing the following data:
            #
            #{
            #    'orcid' => '<orcid>',
            #    'access_token' => '<access_token>',
            #    'refresh_token' => '<refresh-token>',
            #    'name' => '<name>',
            #    'scope' => '/orcid-profile/read-limited',
            #    'token_type' => 'bearer',
            #    'expires_in' => '<expiration-date>'
            #}

            #you can reuse the 'orcid' and 'access_token' to get the user profile

            [200,["Content-Type" => "text/html"],["logged in!"]];

        };

    };


=head1 DESCRIPTION

This is an implementation of L<LibreCat::Auth::SSO> to authenticate against a ORCID (OAuth) server.

It inherits all configuration options from its parent.

=head1 CONFIG

Register the uri of this application in ORCID as a new redirect_uri.

DO NOT register the authorization_url in ORCID as the redirect_uri!

=over 4

=item client_id

client_id for your application (see developer credentials from ORCID)

=item client_secret

client_secret for your application (see developer credentials from ORCID)

=item sandbox

0|1. Defaults to '0'. When set to '1', this api makes use of http://sandbox.orcid.org instead of http://orcid.org.

=back

=head1 SEE ALSO

L<LibreCat::Auth::SSO>

=cut
