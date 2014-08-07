package App::Catalog::Route::admin;

use Catmandu::Sane;
use Catmandu::Util qw(:array);
use Dancer ':syntax';
use App::Catalog::Helper;
use App::Catalog::Controller::Admin qw/:all/;

prefix '/admin' => sub {

	# manage accounts
	get '/account' => sub {
		template 'admin/account';
		# that all, just print stupid template
	};

	post '/account/search' => sub {
		my $p = params;
		my $hits;
		$hits->{hits} = search_person($p);
		template 'admin/account', $hits;
	};

	get '/account/edit/:id' => sub {
		my $id = param 'id';
		my $person = edit_person($id);
		template 'admin/edit_account', $person;
	};

	post '/account/update' => sub {
		my $p = params;
		#save_person(params);
		template 'admin/account';
	};

	get '/account/import/:id' => sub {
		my $p = import_person(params->{id});
		template 'admin/edit_account', $p;
	};

	# manage departments
	get '/admin/department' => sub {};

	# monitoring external sources
	get '/inspire-monitor' => sub {};
};

1;
