package App::Catalog::Import;

use Dancer ':syntax';

get '/new' => sub {
	template 'backend/bnbInputId'; 
};

get '/import/:id' => sub {
	my $id = params->{'id'};
	my $source = h->classifyId($id);
	my $importer = Catmandu->importer($source);
	my $pub =$importer->take(1);
	my $type = $pub->{type};
	template "backend/$type", $pub;	
};

post '/save' => sub {
	my $pub = params;
	h->add_publication($pub);

	if ($pub->{type} eq 'researchData' && !$pub->{doi}) {
		h->registerDoi($pub);
	}
};

1;