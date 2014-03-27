package App::Catalog;

use Catmandu;
use Catmandu::Sane;
use Dancer ':syntax';
#use Dancer::Plugin::Auth::RBAC::Credentials::Catmandu; 

# hook before: login!

use App::Catalog::Import;
use App::Catalog::Helper;
#use App::Catalog::Admin;
use App::Catalog::Publication;
use App::Catalog::Search;
use App::Catalog::Interface;

Catmandu->load;

get '/' => sub {
	redirect h->host;
	#my ($id) = splat;
	
	#my $id = "86212";
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




# get '/submitForm' => sub {
# 	my $params = params;
# 	my $returnhash;
# 	foreach my $key (keys %$params){
# 		$returnhash->{parameters}->{$key} = $params->{$key};
# 	}
	
# 	my $store = Catmandu::Store::MongoDB->new(database_name => 'bnbdb');
# 	my $response = $store->bag->add($returnhash);
	
# 	template "backend/index.tt", {newRec => 'stored'};
# };

get '/login' => sub {};

get '/logout' => sub {
	# do logout
	redirect h->config->{host};
};

1;
