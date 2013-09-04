package App::Catalog::Profile;

use App::Catalog::Helper;
use Dancer ':syntax';

get '/profile' => sub {
	template 'profile.tt';
};

1;
