package App::Search::Route::directoryindex;

use Catmandu::Sane;
use Dancer qw(:syntax);
use App::Helper;

#redirect for old websites
get qr{/\(en\)/*} => sub {
	my $path = h->host . "/en";
	redirect $path, 301;
};

get qr{/\(en\)/(.*)} => sub {
	my ($path) = splat;
	$path = h->host . "/en/" . $path;
	redirect $path, 301;
};

get qr{/workshop/*} => sub {
	forward '/workshop/index.html';
};

get qr{/puboa/*} => sub {
	redirect 'http://oa.uni-bielefeld.de/', 301;
};

get qr{/en/puboa/*} => sub {
	redirect 'http://oa.uni-bielefeld.de/', 301;
};

# The ONLY redirect we will do for the more-than-old /pub? interface
# Redirect old frontdoor requests pub.uni-bielefeld.de/pub?func=drec&id=[id]
# (some of these have been printed in articles...)
get qr{/pub} => sub {
	if(params->{func} and params->{func} eq "drec"){
		if(params->{id}){
			redirect 'https://pub.uni-bielefeld.de/publication/'.params->{id};
		}
	}
	else{
		status 'not_found';
		template 'websites/404', {path => request->{referer}};
	}
};


#general stuff
#get qr{/en/*} => sub {
#	template 'websites/index_publication.tt';
#};

get qr{/doc/api/*|/demo/*|/en/demo/*} => sub {
	my $path = h->host . '/doc/api/index.html';
	redirect $path;
};

get qr{/policy/*|/policy\.html} => sub {
	template 'websites/index_publication.tt', {bag => 'policy'};
};

get qr{/en/policy/*|/en/policy\.html} => sub {
	template 'websites/index_publication.tt', {bag => 'policy', lang => 'en'};
};

get qr{/faq/*|/faq\.html|/erste-schritte\.html} => sub {
	template 'websites/index_publication.tt', {bag => 'faq'};
};

get qr{/en/faq/*|/en/faq\.html|/en/erste-schritte\.html} => sub {
	template 'websites/index_publication.tt', {bag => 'faq', lang => 'en'}
};

get qr{/contact/*|/contact\.html} => sub {
	template 'websites/index_publication.tt', {bag => 'contact'};
};

get qr{/en/contact/*|/en/contact\.html} => sub {
	template 'websites/index_publication.tt', {bag => 'contact', lang => 'en'};
};

get qr{/pubtheses/*} => sub {
    template 'pubtheses/pubtheses.tt', {bag => 'pubtheses'};
};

get qr{/en/pubtheses/*} => sub {
    template 'pubtheses/pubtheses.tt', {bag => 'pubtheses', lang => 'en'};
};

get qr{/about/*} => sub {
    template 'websites/index_publication.tt', {bag => 'about'};
};

get qr{/en/about/*} => sub {
    template 'websites/index_publication.tt', {bag => 'about', lang => 'en'};
};

1;
