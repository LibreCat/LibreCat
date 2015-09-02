package App::Search::Route::api;

=head1 NAME

App::Search::Route::api - handles routes for SRU and OAI interfaces.

=cut

use Catmandu::Sane;
use Dancer qw/:syntax/;
use Dancer::Plugin::Catmandu::OAI;
use Dancer::Plugin::Catmandu::SRU;
use Catmandu::Fix;
use App::Helper;
use Citation;

=head2 GET /sru

Endpoint of the SRU interface.

=cut
sru_provider '/sru';

=head2 GET/POST /oai

Endpoint of the OAI interface.

=cut
oai_provider '/oai',
    deleted => sub {
        defined $_[0]->{date_deleted};
    },
    set_specs_for => sub {
        my $pub = $_[0];
        Catmandu::Fix->new(fixes => [
                "copy_field(type, doc_type)",
                "lookup(doc_type, fixes/lookup/dini_types.csv, default: other)",
                ])->fix($pub);

        my $specs = [$pub->{type}, "doc-type:". $pub->{doc_type}];

        push @$specs, $pub->{ddc};

        if ($pub->{ec_funded} && $pub->{ec_funded} eq '1') {
            if ($pub->{type} eq 'researchData') {
                push @$specs, "openaire_data";
            } else {
                push @$specs, "openaire";
            }
	    }

        if ($pub->{file}->[0]->{open_access} && $pub->{file}->[0]->{open_access} eq '1') {
            push @$specs, "$pub->{type}Ftxt", "driver", "open_access";
        }
        $specs;
    };

get '/livecitation' => sub {
    my $params = params;
    my $debug = $params->{debug} ? "debug" : "no_debug";
    unless ($params->{id} and $params->{style}) {
        return "'id' and 'style' needed.";
    }

    my $pub = h->publication->get($params->{id});

    my $response = Citation::index_citation_update($pub, 1, $debug, [$params->{style}]);

    if($debug eq "debug"){
    	return to_dumper $response;
    }
    else {
    	utf8::decode($response);
    	template "websites/livecitation", {citation => $response};
    }
};

1;
