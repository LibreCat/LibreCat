package App::Catalog::Admin;

use Catmandu::Sane;
use Dancer ':syntax';
use Dancer::Request;
use App::Catalog::Helper;
    
get '/admin' => sub {
	forward '/admin/86212';
};
	
get '/admin/add' => sub {
	template 'edit_researchData.tmpl', {recordOId => "123456789"};#, file => [{fileOId => 1, fileName => "file", accessLevel => "admin", dateLastUploaded => "2014-01-10", isUploadedBy => {login => "kohorst"}}]};
};
	
get qr{/admin/(\d{1,})/*} => sub {
	my ($id) = splat;
	my $personInfo = h->getPerson($id);
	my $sbcatId = $personInfo->{sbcatId};
		
	my $p = {
		q => "person=$id AND hide<>$id",
		facets => "",
		limit => h->config->{store}->{maximum_page_size}
	};
	my $hits = h->search_publication($p);
		
	$hits->{sbcatId} = $sbcatId if $sbcatId;
	$hits->{bisId} = $id;
	my $personStyle;
	my $personSort;
	if($personInfo->{stylePreference} and $personInfo->{stylePreference} =~ /(\w{1,})\.(\w{1,})/){
		$personStyle = $1;
		$personSort = $2;
	}
	$hits->{style} = $personStyle || "pub";
	template 'admin.tt', $hits;
};

get '/admin/update' => sub {
	template 'admin_update';
};

get '/admin/accounts' => sub {
	template 'accounts'
};

get '/admin/curate' => sub {
	template 'curate';
};
	
get '/admin/search_researcher' => sub {
	my $q = params->{'q'};
	my $hits = h->search_researcher({q => $q});
		
	to_dumper $hits;
		
		#my $jsonstring = "[";
		#foreach (@{$hits->{hits}}){
		#	my $mainTitle = $_->{mainTitle};
		#	$mainTitle =~ s/"/\\"/g;
		#	my $citation = $_->{citation}->{$style};
		#	$citation =~ s/"/\\"/g;
		#	$jsonstring .= "{oId:\"" . $_->{oId} . "\", title:\"" . $mainTitle . "\", citation:\"" . $citation . "\"},";
		#}
		#$jsonstring =~ s/,$//g;
		#$jsonstring .= "]";
		#return $jsonstring;
};

1;
