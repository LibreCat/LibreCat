package App::Catalogue;

=head1 NAME

App::Catalogue - The central top level backend module.
Integrates all routes needed for catalogueing records.

=cut

use Catmandu::Sane;
use Catmandu;
use Catmandu::Util qw(:array);
use Dancer ':syntax';
use Dancer::Plugin::Auth::Tiny;
use App::Helper;
use all qw(App::Catalogue::Route::*);

=head2 GET /librecat

The default route after logging in. Will be forwarded
to default search page for current role.

=cut
get '/librecat' => needs login => sub {
    my $params = params;

    if ( session->{role} eq "super_admin" ) {
        forward '/librecat/search/admin', $params;
    }
    elsif ( session->{role} eq "reviewer" ) {
        forward '/librecat/search/reviewer', $params;
    }
    elsif ( session->{role} eq "data_manager" ) {
        forward '/librecat/search/data_manager', $params;
    }
    elsif ( session->{role} eq "delegate" ) {
        forward '/librecat/search/delegate', $params;
    }
    else {
        forward '/librecat/search', $params;
    }
};

=head2 GET /librecat/change_role/:change_role

Let the user change his role.

=cut
get '/librecat/change_role/:role' => needs login => sub {
    my $user = h->get_person( session->{user} );

    # is user allowed to take this role?

    if ( params->{role} eq "delegate" and $user->{delegate} ) {
        session role => "delegate";
    }
    elsif ( params->{role} eq "reviewer" and $user->{reviewer} ) {
        session role => "reviewer";
    }
    elsif ( params->{role} eq "data_manager" and $user->{data_manager} ) {
        session role => "data_manager";
    }
    elsif ( params->{role} eq "admin" and $user->{super_admin} ) {
        session role => "super_admin";
    }
    else {
        session role => "user";
    }
    redirect '/librecat';
};

1;
