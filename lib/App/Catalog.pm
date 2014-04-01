package App::Catalog;

use Catmandu;
use Catmandu::Sane;
use Dancer ':syntax';
use Catmandu::Util qw(:array);
use App::Catalog::Admin;
use App::Catalog::Helper;
use App::Catalog::Import;
use App::Catalog::Interface;
use App::Catalog::Person;
use App::Catalog::Publication;
use App::Catalog::Search;

use Authentication::Authenticate;

Catmandu->load;

# hook_before => sub {
# 	if( ! session('user') && request->path_info !~ m{login} ) {
# 		var requested_path => request->path_info;
# 		request->path_info('/login');
# 	}
# };

any '/' => sub {
    my $params = params;

    forward 'search', $params;
};

get '/login' => sub {
	my $error;
	$error->{error_message} = params->{error_message} if params->{error_message};
    template 'login', $error;
};

post '/login' => sub {

    #my $auth = auth( params->{user}, params->{pass} );
    
    #return to_dumper ($auth->errors);
    
    #if ( !$auth->errors ) {
    	
    	my $bag= Catmandu->store('authority')->bag;
    	my $user = h->getAccount(params->{user});
    	
    	
    	# >>>> LDAP
    	if($user){
    		#username is in PUB
    		#return to_dumper verifyUser(params->{user}, params->{pass});
    		if (verifyUser(params->{user}, params->{pass})) {
    			session role => $user->[0]->{isSuperAdminAccount} ? "superAdmin" : "user";
    			session user => $user->[0]->{user}->{login};
    			session personNumber => $user->[0]->{user}->{personNumber};
    			forward '/myPUB/search', {}, {method => 'GET'};
    			#return to_dumper session;
    		}
    		else {
    			forward '/myPUB/login', {error_message => "Wrong username or password!"}, {method => 'GET'};
    		}
    	}
    	else {
    		forward '/myPUB/login', {error_message => "No such user in PUB. Please register first!"}, {method => 'GET'};
    	}
    	
    	# LDAP <<<<
        
        #return to_dumper session;

        #if ( $auth->can( 'manage_accounts', 'create' ) ) { }

        #session role => ;
        #redirect params->{path} || '/';
    #}
    #else {
    #    redirect '/myPUB/login?failed=1';
    #}

};

get '/logout' => sub {
    session->destroy;    # that's it?
    redirect '/myPUB/login';
};

1;
