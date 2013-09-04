package App::Catalog::Publication;

use App::Catalog::Helper;
use Dancer ':syntax';

prefix '/record' => sub {

	# 
	get '/' => sub {
		my $id = shift;
		my $hits = h->bag->search(cql_query => "person exact $id");
		template 'list', $hits;
	};

	get '/new' => sub {
		# here comes add function
		template 'add_new';
	};

	get '/import' => sub {
		my $id = param 'id';
		my $pkg = h->classifyId($id);
		(!$pkg) && (return "Error");
		my $importer = Catmandu->importer($pkg);	
	};

	# deleting records, for admins only
	del '/:id' => sub {
		my $id = params 'id';
		h->bag->delete($id);
	};

};

1;
