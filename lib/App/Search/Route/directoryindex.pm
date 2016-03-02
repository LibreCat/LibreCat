package App::Search::Route::directoryindex;

use Catmandu::Sane;
use Dancer qw(:syntax);
use App::Helper;
use Try::Tiny;

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
        my $redirect_url = 'https://pub.uni-bielefeld.de/publication?';
        my $redirect_params = '';
        $redirect_params .= "&q=year=\"" .       params->{publyear} . "\"" if params->{publyear};
        $redirect_params .= "&q=person=\"" .     params->{author} .   "\"" if params->{author};
        $redirect_params .= "&q=person=\"" .     params->{editor} .   "\"" if params->{editor};
        $redirect_params .= "&q=department=\"" . params->{dept} .     "\"" if params->{dept};
        $redirect_params .= "&q=type=" .         params->{doctype}         if params->{doctype};
        $redirect_params .= "&q=project=\"" .    params->{project} .  "\"" if params->{project};
        $redirect_params .= "&q=title=\"" .      params->{title} .    "\"" if params->{title};
        $redirect_params .= "&q=type=\"" .       params->{doctype} .  "\"" if params->{doctype};
        $redirect_params .= "&q=fulltext=" .     params->{fulltext}        if params->{fulltext};
        $redirect_params .= "&q=extern=" .       params->{extern}          if params->{extern};
        
        $redirect_params .= "&style=" . params->{style} if params->{style};
        $redirect_params .= "&ftyp=" . params->{ftyp} if params->{ftyp};
        $redirect_params .= "&ftyp=iframe" if !params->{ftyp};
        $redirect_params .= "&sort=" . params->{sortc} . "." . params->{sorto} if params->{sortc} and params->{sorto};
        $redirect_params .= "&sort=" . params->{sortc} . ".desc" if params->{sortc} and !params->{sorto};
        $redirect_params .= "&sort=year." . params->{sorto} if params->{sorto} and !params->{sortc};
        $redirect_params .= "&limit=" . params->{maxrecs} if params->{maxrecs};
        $redirect_params .= "&start=" . params->{startrecs} if params->{startrecs};
        
        $redirect_params =~ s/^\&//g;
        
        redirect $redirect_url . $redirect_params;
        
#       if(params->{ftyp} and params->{ftyp} eq "js"){
#           header("Content-Type" => "text/plain");
#           template 'docs/error_message/pub_list_js.tt', {interface_warning => 'Diese Schnittstelle zur Einbettung von Publikationslisten wird nicht mehr bedient. Bitte wenden Sie sich an <a href="mailto:publikationsdienste.ub@uni-bielefeld.de">publikationsdienste.ub@uni-bielefeld.de</a>, um die Einbettung umzustellen.'};
#       }
#       else {
#           template 'docs/error_message/pub_list.tt', {interface_warning => 'Diese Schnittstelle zur Einbettung von Publikationslisten wird nicht mehr bedient. Bitte wenden Sie sich an <a href="mailto:publikationsdienste.ub@uni-bielefeld.de">publikationsdienste.ub@uni-bielefeld.de</a>, um die Einbettung umzustellen.'};
#       }
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

get qr{/docs/*} => sub {
    redirect "docs/howto/start";
};

get qr{/docs/(.*)} => sub {
    my ($path) = splat;
    try {
        template "docs/$path";
    } catch {
        status 'not_found';
        template 'websites/404', {path => request->{referer}};
    }
};

1;
