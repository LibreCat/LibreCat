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

use Authentication::Authenticate;

# make variables with leading '_' visible in TT
$Template::Stash::PRIVATE = 0;

hook 'before' => sub {
    if ( !session('user') && request->path_info !~ m{login} ) {
        var requested_path => request->path_info;
        request->path_info('/myPUB/login');
    }
};

get '/' => sub {
    my $params = params;

    if(session->{role} eq "super_admin"){
    	forward '/myPUB/search/admin', $params;
    }
    elsif(session->{role} eq "reviewer"){
        forward '/myPUB/search/reviewer', $params;
    }
    elsif(session->{role} eq "dataManager"){
    	forward '/myPUB/search/datamanager', $params;
    }
    else{
        forward '/myPUB/search', $params;
    }
};

get '/login' => sub {
    my $data = { path => vars->{requested_path} };
    $data->{error_message} = params->{error_message} ||= '';
    $data->{login} = params->{login} ||= "";
    template 'login', $data;
};

post '/login' => sub {

	if(!params->{user} || !params->{pass}){
		forward '/myPUB/login', { error_message => "Please enter your username AND password!", login => params->{user}}, { method => 'GET' };
	}

    my $bag  = Catmandu->store('authority')->bag;
    my $user = h->getAccount( params->{user} );

    if ($user) {

        #username is in PUB
        my $verify = verifyUser(params->{user}, params->{pass});

        if ($verify and $verify ne "error") {
        	my $super_admin = "super_admin" if $user->[0]->{super_admin};
        	my $reviewer = "reviewer" if $user->[0]->{reviewer};
        	my $dataManager = "dataManager" if $user->[0]->{dataManager};
            session role => $super_admin || $reviewer || $dataManager || "user";
            session user         => $user->[0]->{login};
            session personNumber => $user->[0]->{_id};
            my $params;
            $params->{path} = params->{path} if params->{path};

            if(session->{role} eq "super_admin"){
            	$params->{path} ? redirect $params->{path} : redirect '/myPUB/search/admin';
            }
            elsif(session->{role} eq "reviewer"){
            	$params->{path} ? redirect $params->{path} : redirect '/myPUB/search/reviewer';
            }
            elsif(session->{role} eq "dataManager"){
            	$params->{path} ? redirect $params->{path} : redirect '/myPUB/search/datamanager';
            }
            else{
            	$params->{path} ? redirect $params->{path} : redirect '/myPUB/search';
            }
        }
        else {
            forward '/myPUB/login', { error_message => "Wrong username or password!" }, { method => 'GET' };
        }
    }
    else {
        forward '/myPUB/login', { error_message => "No such user in PUB. Please register first!" }, { method => 'GET' };
    }
};

get '/logout' => sub {
    session->destroy;
    redirect '/myPUB/login';
};

get '/change_role/:role' => sub {
    my $user = h->getAccount( session->{user} )->[0];

    # is user allowed to take this role?

    if(params->{role} eq "reviewer" and $user->{reviewer}){
    	session role => "reviewer";
    }
    elsif(params->{role} eq "dataManager" and $user->{dataManager}){
    	session role => "dataManager";
    }
    elsif(params->{role} eq "admin" and $user->{super_admin}){
    	session role => "super_admin";
    }
    else{
    	session role => "user";
    }
    redirect '/myPUB';
};

1;
