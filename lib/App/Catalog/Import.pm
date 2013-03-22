package App::Catalog::Import;

use Dancer ':syntax';

get '/' => sub {
	template 'backend/index';
}

get '/new' => sub {
	template 'backen/bnbInputId'; 
};

get '/import/:id' => sub {
	my $id = params->{'id'};
	my $source = h->classifyID($id);
	my $importer = Catmandu->importer($source);
	
}

1;