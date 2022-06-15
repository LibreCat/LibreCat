package LibreCat::App::Catalogue;

=head1 NAME

LibreCat::App::Catalogue - The central top level backend module.
Integrates all routes needed for catalogueing records.

=cut

use Catmandu::Sane;
use Catmandu;
use Catmandu::Util qw(:array);
use Dancer ':syntax';
use LibreCat::App::Helper;
use all qw(LibreCat::App::Catalogue::Route::*);

=head2 GET /librecat

The default route after logging in. Will be redirected
to default search page for current role.

=cut

get '/librecat' => sub {
    my $params = params("query");

    if (session->{role} eq "super_admin") {
        redirect( uri_for( '/librecat/search/admin', $params ) );
    }
    elsif (session->{role} eq "reviewer") {
        redirect( uri_for( '/librecat/search/reviewer', $params ) );
    }
    elsif (session->{role} eq "project_reviewer") {
        redirect( uri_for( '/librecat/search/project_reviewer', $params ) );
    }
    elsif (session->{role} eq "data_manager") {
        redirect( uri_for( '/librecat/search/data_manager', $params ) );
    }
    elsif (session->{role} eq "delegate") {
        redirect( uri_for( '/librecat/search/delegate', $params ) );
    }
    else {
        redirect( uri_for( '/librecat/search', $params ) );
    }
};

=head2 GET /librecat/change_role/:change_role

Let the user change his role.

=cut

get '/librecat/change_role/:role' => sub {
    my $user = h->current_user;

    # is user allowed to take this role?

    if (params->{role} eq "delegate" and $user->{delegate}) {
        session role => "delegate";
    }
    elsif (params->{role} eq "reviewer" and $user->{reviewer}) {
        session role => "reviewer";
    }
    elsif (params->{role} eq "project_reviewer" and $user->{project_reviewer})
    {
        session role => "project_reviewer";
    }
    elsif (params->{role} eq "data_manager" and $user->{data_manager}) {
        session role => "data_manager";
    }
    elsif (params->{role} eq "admin" and $user->{super_admin}) {
        session role => "super_admin";
    }
    else {
        session role => "user";
    }

    redirect uri_for('/librecat');
};

1;
