package App::Catalogue;

=head1 NAME

App::Catalogue - The central top level backend module.

Integrates all routes needed for catalogueing records.

=cut

use Catmandu::Sane;
use Catmandu;
use Dancer ':syntax';
use Catmandu::Util qw(:array);

use App::Helper;
use App::Catalogue::Interface;
use Dancer::Plugin::Auth::Tiny;
use App::Catalogue::Route::admin;
use App::Catalogue::Route::importer;
use App::Catalogue::Route::person;
use App::Catalogue::Route::publication;
use App::Catalogue::Route::search;
use App::Catalogue::Route::file;
use App::Catalogue::Route::upload;

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
        forward '/myPUB/search/data_manager', $params;
    }
    elsif ( session->{role} eq "delegate" ) {
    	forward '/myPUB/search/delegate', $params;
    }
    else {
        forward '/myPUB/search', $params;
    }
};

=head2 GET /myPUB/change_role/:change_role

Let the user change his role.

=cut
get '/myPUB/change_role/:role' => needs login => sub {
    my $user = h->getAccount( session->{user} )->[0];

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
    redirect '/myPUB';
};

1;
