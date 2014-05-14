package App::Catalog::Route::import;

use Dancer ':syntax';
use App::Catalog::Helper;

post '/import' => sub {
	my $params = params('body');
	my $id = params->{'id'};
	my $pub = _process_import($id);
	template "backend/forms/$pub->{type}", $pub;
};

# for admins only? otherwise: garbage collection in db
post '/import/bibtex/:bibtex' => sub {
	my $bibtex = params 'bibtex';
	my $importer = Catmandu->importer('bibtex');
};

1;
