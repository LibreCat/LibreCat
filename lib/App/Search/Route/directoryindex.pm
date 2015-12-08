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
	elsif(params->{func} and params->{func} eq "plst"){
		header("Content-Type" => "text/plain");
		template 'docs/error_message/pub_list_js.tt', {interface_warning => 'Diese Schnittstelle zur Einbettung von Publikationslisten wird nicht mehr bedient. Bitte wenden Sie sich an <a href="mailto:publikationsdienste.ub@uni-bielefeld.de">publikationsdienste.ub@uni-bielefeld.de</a>, um die Einbettung umzustellen.'};
	}
	else{
		status 'not_found';
		template 'websites/404', {path => request->{referer}};
	}
};

get qr{/policy/*|/policy\.html} => sub {
	#template 'websites/index_publication.tt', {bag => 'policy'};
	redirect 'docs/howto/policy';
};

get qr{/en/policy/*|/en/policy\.html} => sub {
	#template 'websites/index_publication.tt', {bag => 'policy', lang => 'en'};
	session lang => "en";
	redirect 'docs/howto/policy';
};

get qr{/faq/*|/faq\.html|/erste-schritte\.html} => sub {
	#template 'websites/index_publication.tt', {bag => 'faq'};
	redirect 'docs/howto';
};

get qr{/en/faq/*|/en/faq\.html|/en/erste-schritte\.html} => sub {
	#template 'websites/index_publication.tt', {bag => 'faq', lang => 'en'}
	session lang => "en";
	redirect 'docs/howto';
};

get qr{/contact/*|/contact\.html} => sub {
	#template 'websites/index_publication.tt', {bag => 'contact'};
	redirect 'docs/howto/contact';
};

get qr{/en/contact/*|/en/contact\.html} => sub {
	#template 'websites/index_publication.tt', {bag => 'contact', lang => 'en'};
	session lang => "en";
	redirect 'docs/howto/contact';
};

get qr{/about/*} => sub {
    #template 'websites/index_publication.tt', {bag => 'about'};
    redirect 'docs/howto/start';
};

get qr{/en/about/*} => sub {
    #template 'websites/index_publication.tt', {bag => 'about', lang => 'en'};
    session lang => "en";
    redirect 'docs/howto/start';
};

get qr{/workshop/*} => sub {
	#forward '/workshop/index.html';
	redirect '/docs/workshop/index.html', 301;
};

get qr{/workshop/(.*)} => sub {
	my ($path) = splat;
	redirect "/docs/workshop/" . $path;
};

get qr{/pubtheses/*} => sub {
    template 'pubtheses/pubtheses.tt', {bag => 'pubtheses'};
};

get qr{/en/pubtheses/*} => sub {
    template 'pubtheses/pubtheses.tt', {bag => 'pubtheses', lang => 'en'};
};

1;
