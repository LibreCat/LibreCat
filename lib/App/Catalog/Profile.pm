package App::Catalog::Profile;

use App::Catalog::Helper;
use Dancer ':syntax';

get '/profile' => sub {
	template 'profile';
};

post '/profile/save' => sub {
	my $p = params;
	to_dumper $p;
	return "msg. saved.";
};

1;
