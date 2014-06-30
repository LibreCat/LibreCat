package App::Catalog::Route::import;

use Dancer ':syntax';
use App::Catalog::Helper;
use App::Catalog::Controller::Import qw/arxiv crossref/;


post '/import' => sub {
	my $params = params('body');
	my $id = params->{'id'};
	my $pub = import_from_id($id);
	template "backend/forms/$pub->{type}", $pub;
};

# for admins only? otherwise: garbage collection in db
post '/import/bibtex/:bibtex' => sub {
	my $bibtex = params 'bibtex';
	my $importer = Catmandu->importer('bibtex');
};

get '/test/:pkg/:id' => sub {
	my $pub = params->{pkg}(params->{id});
	return to_dumper $pub;
}

1;
