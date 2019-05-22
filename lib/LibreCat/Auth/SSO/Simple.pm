package LibreCat::Auth::SSO::Simple;

use Catmandu::Sane;
use Catmandu::Util qw(:is);
use LibreCat qw(user);
use Moo;

with "LibreCat::Auth::SSO";

sub logged_in {

    my $self = $_[0];

    [
        302,
        [
            "Content-Type" => "text/html",
            Location       => $self->uri_for($self->success_path)
        ],
        []
    ];

}

sub access_denied {

    my $self = $_[0];

    [
         302,
         [
             "Content-Type" => "text/html",
             Location       => $self->uri_for($self->denied_path)
         ],
         []
     ];

}

sub to_app {

    my $self = $_[0];

    sub {

        my $env = $_[0];

        my $request = Plack::Request->new($env);
        my $session = Plack::Session->new($env);
        my $model   = user();

        #user is already logged in. Please logout first
        if( $model->is_session( $session ) ){

            return $self->logged_in();

        }

        #got response from external authentication server
        my $auth_sso = $self->get_auth_sso( $session );

        if (is_hash_ref($auth_sso)) {

            #remove auth_sso.
            # -> Use case:
            #       external authentication server returns record, but cannot be found in the whitelist
            #       keeping this would make it impossible to return to the authentication server
            # -> No need to keep it anyway
            $self->remove_auth_sso($session);

            my $user = $model->find_by_username($auth_sso->{uid});

            if ($user) {

                my %attrs = $model->to_session($user);

                for (keys %attrs) {

                    $session->set($_ => $attrs{$_});

                }

                return $self->logged_in();

            }
            else {

                return $self->access_denied();

            }

        }
        else {

            return $self->access_denied();

        }

    };

}

=pod

=head1 NAME

LibreCat::Auth::SSO::Simple - uid based implementation of LibreCat::Auth::SSO

=head1 SYNOPSIS

#somewhere in your dancer psgi

builder {

    mount "/authorize/sso" => LibreCat::Auth::SSO::Simple->new(
        uri_base => "http://localhost:5001",
        session_key => "auth_sso",
        success_path => "/",
        denied_path => "/access_denied"
    )->to_app();

};

=head1 DESCRIPTION

This is an implementation of L<LibreCat::Auth::SSO>.

What it does:

* find user by user->find_by_username( $auth_sso->{uid} )

* convert user to session attributes using user->to_session

* save attributes to session

It inherits all configuration options from its parent.

=head1 SEE ALSO

L<LibreCat::Auth::SSO>

L<Plack::Auth::SSO>

=cut

1;
