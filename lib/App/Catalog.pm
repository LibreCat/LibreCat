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

hook_before => sub {
	if( ! session('user') && request->path_info !~ m{login} ) {
		var requested_path => request->path_info;
		request->path_info('/login');
	} 
};

any '/' => sub {
	my $params = params;
	my $id = params->{id} ? params->{id} : "73476";
	my $personInfo = h->getPerson($id);
	my $sbcatId = $personInfo->{sbcatId};
		
	$params->{q} = "person=$id AND hide<>$id" if !$params->{q};
	$params->{limit} = h->config->{store}->{maximum_page_size} if !$params->{limit};
		
	$params->{sbcatId} = $sbcatId if $sbcatId;
	$params->{bisId} = $id;
	my $personStyle;
	my $personSort;
	if($personInfo->{stylePreference} and $personInfo->{stylePreference} =~ /(\w{1,})\.(\w{1,})/){
		if(array_includes(h->config->{lists}->{styles},$1)){
			$personStyle = $1 unless $1 eq "pub";
		}
		$personSort = "publishingyear." . $2;
	}
	elsif($personInfo->{stylePreference} and $personInfo->{stylePreference} !~ /\w{1,}\.\w{1,}/){
		if(array_includes(h->config->{lists}->{styles},$personInfo->{stylePreference})){
			$personStyle = $personInfo->{stylePreference} unless $personInfo->{stylePreference} eq "pub";
		}
	}
	
	if($personInfo->{sortPreference}){
		$personSort = $personInfo->{sortPreference};
	}
	$params->{personStyle} = $personStyle || "";
	$params->{personSort} = $personSort || "";
	handle_request($params);
};

get '/login' => sub {
	template 'login';
};

post '/login' => sub {

	my $auth = auth(params->{user}, params->{pass});
    if (! $auth->errors) {
     
        if ($auth->asa('guest')) {}
         
        if ($auth->can('manage_accounts', 'create')) {}

        session user => params->{user};
        #session role => ;
        redirect params->{path} || '/';
    }
    else {
        redirect 'login?failed=1';
    }

};

get '/logout' => sub {
	session->destroy; # that's it?
	redirect h->config->{host};
};

1;
