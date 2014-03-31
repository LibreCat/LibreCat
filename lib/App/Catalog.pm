package App::Catalog;

use Catmandu;
use Catmandu::Sane;
use Dancer ':syntax';
use Dancer::Plugin::Auth::RBAC::Credentials::Catmandu;
use Catmandu::Util qw(:array);
use App::Catalog::Admin;
use App::Catalog::Helper;
use App::Catalog::Import;
use App::Catalog::Interface;
use App::Catalog::Person;
use App::Catalog::Publication;
use App::Catalog::Search;

Catmandu->load;

# hook_before => sub {
# 	if( ! session('user') && request->path_info !~ m{login} ) {
# 		var requested_path => request->path_info;
# 		request->path_info('/login');
# 	}
# };

any '/' => sub {
    my $params = params;

    forward '/search', $params;
};

get '/login' => sub {
    template 'login';
};

post '/login' => sub {

    my $auth = auth( params->{user}, params->{pass} );
    if ( !$auth->errors ) {

        if ( $auth->asa('guest') ) { }

        if ( $auth->can( 'manage_accounts', 'create' ) ) { }

        session user => params->{user};

        #session role => ;
        redirect params->{path} || '/';
    }
    else {
        redirect 'login?failed=1';
    }

};

get '/logout' => sub {
    session->destroy;    # that's it?
    redirect h->config->{host};
};

1;
