package App::Catalog::Route::search;

use Catmandu::Sane;
use Dancer qw/:syntax/;
use App::Catalog::Helper;
use App::Catalog::Controller::Search;


get '/adminSearch' => sub {
    my $params = params;

    (session->{role} ne "superAdmin") && (redirect '/myPUB/reviewerSearch');   
    
    $params->{modus} = "admin";
    search($params);

};

get '/reviewerSearch' => sub {
    my $params = params;

    (session->{role} ne "superAdmin" and $role ne "reviewer")
    	&& (redirect '/myPUB/search');

    $params->{modus} = "reviewer";
    search($params);

};

get '/datamanagerSearch' => sub {
    my $params = params;

    (session->{role} ne "superAdmin" and $role ne "dataManager")
    	&& (redirect '/myPUB/search');

    $params->{modus} = "dataManager";
    search($params);

};

get '/search' => sub {
    my $params = params;

    $params->{modus} = "user";
    search($params);

};

1;
