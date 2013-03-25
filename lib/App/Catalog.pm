package App::Catalog;

use lib qw(/srv/www/sbcat/lib /srv/www/sbcat/lib/extension /srv/www/sbcat/lib/default);
use Catmandu;
use Catmandu::Sane;
use Dancer ':syntax';
use Catmandu::Store::MongoDB;
use App::Import;

#sub store {
#  state $store = Catmandu->store;
#}
#
#sub bag {
#  state $bag = &store->bag;
#}

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