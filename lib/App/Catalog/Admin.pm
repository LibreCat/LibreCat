package App::Catalog::Admin;

use Catmandu::Sane;
use Dancer ':syntax';

get '/admin' => sub {
	my $p = params;

};

get '/admin/authority' => sub {
	#dfs
};

get '/admin/curate' => sub {
	# my curator
};

1;