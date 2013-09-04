package App::Catalog::Admin;

use Catmandu::Sane;
use Dancer ':syntax';

prefix '/admin' => sub {

	get '/' => sub {
		template 'admin';
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

};

1;
