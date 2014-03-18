package App::Catalog::Import;

use Dancer ':syntax';

get '/import/:id' => sub {
	my $id = params->{'id'};
	my $source = h->classifyId($id);
	my $importer = Catmandu->importer($source);
	my $pub =$importer->first;
	my $type = $pub->{type};
	template "backend/$type", $pub;
};

# for admins only? otherwise: garbage collection in db
post '/import/bibtex/:bibtex' => sub {
	my $bibtex = params 'bibtex';
	my $importer = Catmandu->importer('bibtex');
};

1;
