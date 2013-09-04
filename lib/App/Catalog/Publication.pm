package App::Catalog::Publication;

package App::Catalog::Profile;

use App::Catalog::Helper;
use Dancer ':syntax';

get '/add' => sub {
	# here comes add function
	template 'add_new';
};

get '/import' => sub {
	my $id = param 'id';
	my $pkg = h->classifyId($id);
	(!$pkg) && (return "Error");
	my $importer = Catmandu->importer($pkg);	
};



1;
