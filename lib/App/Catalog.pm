package App::Catalog;

use Catmandu;
use Catmandu::Sane;
use Dancer ':syntax';
# the longest module name known to me
#use Dancer::Plugin::Auth::RBAC::Credentials::Catmandu; 

# hook before
## login!

use App::Catalog::Import;
use App::Catalog::Helper;

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

get '/importId' => sub {
	#my $documentId = params->{documentId} ||= "";
	#my $idType = App::Import::identifyId($documentId);
	
	template "backend/header.tt";
};


get '/' => sub {
	my $newRec;
	
	$newRec = params->{newRec} if params->{newRec};
	
	my $hits;
	$hits->{parameters} = params;
	$hits->{newRec} = $newRec if $newRec;
	
    template 'backend/index.tt', $hits;
};

"The truth is out there";
