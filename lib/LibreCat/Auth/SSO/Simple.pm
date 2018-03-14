package LibreCat::Auth::SSO::Simple;

use Catmandu::Sane;
use Catmandu::Util qw(:is);
use LibreCat;
use Moo;

with "LibreCat::Auth::SSO";

sub to_app {

    my $self = $_[0];

    sub {

        my $env = $_[0];

        my $request = Plack::Request->new( $env );
        my $session = Plack::Session->new( $env );

        my $auth_sso = $self->get_auth_sso($session);

        if ( is_hash_ref( $auth_sso ) ) {

            my $user = LibreCat->user->find_by_username( $auth_sso->{uid} );

            if ( $user ) {

                my %attrs = LibreCat->user->to_session( $user );

                for ( keys %attrs ) {

                    $session->set( $_ => $attrs{$_} );

                }

                return
                    [ 302, [ "Content-Type" => "text/html", Location => $self->uri_for( $self->success_path ) ], [] ];

            }
            else {

                return
                    [ 302, [ "Content-Type" => "text/html", Location => $self->uri_for( $self->denied_path ) ], [] ];

            }

        }
        else {

            return
                [ 302, [ "Content-Type" => "text/html", Location => $self->uri_for( $self->denied_path ) ], [] ];

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

* find user by LibreCat->user->find_by_username( $auth_sso->{uid} )

* convert user to session attributes using LibreCat->user->to_session

* save attributes to session

It inherits all configuration options from its parent.

=head1 SEE ALSO

L<LibreCat::Auth::SSO>

L<Plack::Auth::SSO>

=cut

1;
