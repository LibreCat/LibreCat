package App::Catalog::Test;

use Catmandu;
use Catmandu::Sane;
use Dancer ':syntax';
use Sys::Hostname::Long;
use App::Catalog::Helper;

prefix '/test' => sub {

	get '/host' => sub {
		return h->host, h->shost;
	};
};

1;

