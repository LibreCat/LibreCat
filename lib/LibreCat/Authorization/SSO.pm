package LibreCat::Authorization::SSO;

use Catmandu::Sane;
use Catmandu::Util qw(:is :check);
use Moo::Role;

has session_key => (
    is       => "ro",
    isa      => sub { check_string( $_[0] ); },
    lazy     => 1,
    default  => sub { "auth_sso" },
    required => 1
);

has success_path => (
    is       => "ro",
    isa      => sub { check_string( $_[0] ); },
    lazy     => 1,
    default  => sub { "/"; },
    required => 1
);

has denied_path => (
    is       => "ro",
    isa      => sub { check_string( $_[0] ); },
    lazy     => 1,
    default  => sub { "/access_denied"; },
    required => 1
);

has uri_base => (
    is       => "ro",
    isa      => sub { check_string( $_[0] ); },
    required => 1,
    default  => sub { "http://localhost:5000"; }
);

requires "to_app";

sub uri_for {

    my ($self, $path) = @_;
    $self->uri_base() . $path;

}

sub _check_plack_session {

    defined( $_[0]->session )
        or die( "LibreCat::Authorization::SSO requires a Plack::Session" );

}

sub get_auth_sso {

    my ($self, $session) = @_;
    _check_plack_session( $session );
    $session->get( $self->session_key );

}

=pod

=head1 NAME

LibreCat::Authorization::SSO - role for Single Sign On (SSO) authorization

=head1 IMPLEMENTATIONS

* Simple: L<LibreCat::Authorization::SSO::Simple>

=head1 DESCRIPTION

This is a Moo::Role for all Single Sign On Authorization packages.

It requires C<to_app> method, that returns a valid Plack application.

This application must do the following:


    * check whether "auth_sso" is set in the current Plack session. See L<Plack::Auth::SSO>

    * use data in "auth_sso" to set the session keys user, user_id, role and lang.

    * redirect to "success_path" if user is found. Use the method $self->uri_for for this.

    * redirect to denied_path if user not found

This package requires you to use Plack Sessions.

=head1 CONFIG

=over 4

=item session_key

Session key where the auth_sso hash is stored.

See L<Plack::Auth::SSO>

Default: "auth_sso"

=item success_path

(internal) path where where user must be redirected to after a successfull login

Default: "/"

=item denied_path

(internal) path where where user must be redirected when user was not found

Default: "/access_denied"

=item uri_base

base url of the Plack application

Default: "http://localhost:5001"

=back

=cut

1;
