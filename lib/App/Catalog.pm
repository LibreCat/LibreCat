package App::Catalog;

=head1 NAME

    App::Catalog - The central top level backend module.
    Integrates all routes needed for catalogueing records.

=cut

use Catmandu::Sane;
use Catmandu;
use Dancer ':syntax';
use Catmandu::Util qw(:array);

use App::Catalog::Helper;
use App::Catalog::Interface;
use Dancer::Plugin::Auth::Tiny;
use App::Catalog::Route::admin;
use App::Catalog::Route::import;
use App::Catalog::Route::person;
use App::Catalog::Route::publication;
use App::Catalog::Route::search;
use App::Catalog::Route::file;

=head2 GET /myPUB

    The default route after logging in. Will be forwarded
    to default search page for current role.

=cut
get '/myPUB' => needs login => sub {
    my $params = params;

    if ( session->{role} eq "super_admin" ) {
        forward '/myPUB/search/admin', $params;
    }
    elsif ( session->{role} eq "reviewer" ) {
        forward '/myPUB/search/reviewer', $params;
    }
    elsif ( session->{role} eq "dataManager" ) {
        forward '/myPUB/search/datamanager', $params;
    }
    else {
        forward '/myPUB/search', $params;
    }
};

=head2 GET /myPUB/change_role/:change_role

    Let's the user change his role.

=cut
get '/myPUB/change_role/:role' => needs login => sub {
    my $user = h->getAccount( session->{user} )->[0];

    # is user allowed to take this role?

    if ( params->{role} eq "reviewer" and $user->{reviewer} ) {
        session role => "reviewer";
    }
    elsif ( params->{role} eq "dataManager" and $user->{dataManager} ) {
        session role => "dataManager";
    }
    elsif ( params->{role} eq "admin" and $user->{super_admin} ) {
        session role => "super_admin";
    }
    else {
        session role => "user";
    }
    redirect '/myPUB';
};

1;
