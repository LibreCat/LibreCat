package App::Search;

use Catmandu::Sane;
use Dancer qw(:syntax);

use all qw(App::Search::Route::*);
use App::Helper;

get qr{/en/*} => sub {
	session lang => "en";
	template '/websites/index_publication.tt', {bag => "home"};
};

get '/' => sub {
	if(!session->{lang}){
		session lang => "de";
	}
    template '/websites/index_publication.tt', {bag => "home"};
};

1;
