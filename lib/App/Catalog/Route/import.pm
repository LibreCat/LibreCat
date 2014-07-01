package App::Catalog::Route::import;

use Dancer ':syntax';
#use App::Catalog::Helper;
use App::Catalog::Controller::Import;

post '/import' => sub {
	my $p = params;
	# returns template if something is missing
	return template "add_new" unless $p->{source} && $p->{id};
	my $pub = import_publication($p->{source}, $p->{id});

	#error handling!
	template "backend/forms/$pub->{type}", $pub;
};

1;
