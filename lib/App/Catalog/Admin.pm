package App::Catalog::Admin;

use Catmandu::Sane;
use Dancer ':syntax';
use App::Catalog::Helper;

prefix '/admin' => sub {
    
    get '/add' => sub {
		template 'edit_researchData.tmpl', {recordOId => "123456789", file => [{fileOId => 1, fileName => "file", accessLevel => "admin", dateLastUploaded => "2014-01-10", isUploadedBy => {login => "kohorst"}}]};
	};
	
	get '/:id' => sub {
		my $id = params->{id};
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

	get '/update' => sub {
		template 'admin_update';
	};

	get '/accounts' => sub {
		template 'accounts'
	};

	get '/curate' => sub {
		template 'curate';
	};
	
	get '/' => sub {
		forward '/admin/86212';
	};

};

1;
