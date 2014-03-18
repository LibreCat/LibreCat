package App::Catalog;

use Catmandu;
use Catmandu::Sane;
use Dancer ':syntax';
#use Dancer::Plugin::Auth::RBAC::Credentials::Catmandu; 

# hook before: login!

use App::Catalog::Import;
use App::Catalog::Helper;
use App::Catalog::Admin;
use App::Catalog::Publication;
use App::Catalog::Search;
use App::Catalog::Interface;

Catmandu->load;

get '/' => sub {
	redirect h->host;
};

get '/submitForm' => sub {
	my $params = params;
	my $returnhash;
	foreach my $key (keys %$params){
		$returnhash->{parameters}->{$key} = $params->{$key};
	}
	
	my $store = Catmandu::Store::MongoDB->new(database_name => 'bnbdb');
	my $response = $store->bag->add($returnhash);
	
	template "backend/index.tt", {newRec => 'stored'};
};

get '/login' => sub {};

get '/logout' => sub {
	# do logout
	redirect h->config->{host};
};

1;
