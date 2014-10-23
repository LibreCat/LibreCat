package App::Catalog;

use Catmandu::Sane;
use Catmandu;
use Dancer ':syntax';
use Catmandu::Util qw(:array);

use App::Catalog::Helper;
use App::Catalog::Interface;

use App::Catalog::Route::admin;
use App::Catalog::Route::import;
use App::Catalog::Route::person;
use App::Catalog::Route::publication;
use App::Catalog::Route::search;

use Dancer::Plugin::Auth::Tiny;

get '/' => needs login => sub {
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


get '/change_role/:role' => needs login => sub {
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
