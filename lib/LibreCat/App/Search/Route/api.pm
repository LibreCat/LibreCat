package LibreCat::App::Search::Route::api;

=head1 NAME

LibreCat::App::Search::Route::api - handles routes for SRU and OAI interfaces.

=cut

use Catmandu::Sane;
use Dancer qw/:syntax/;
use Dancer::Plugin::Catmandu::OAI;
use Dancer::Plugin::Catmandu::SRU;
use Catmandu::Util qw(:is);
use Catmandu::Fix;
use LibreCat::App::Helper;
use LibreCat::Citation;

=head2 GET /sru

Endpoint of the SRU interface.

=cut

sru_provider '/sru';

=head2 GET/POST /oai

Endpoint of the OAI interface.

=cut

oai_provider '/oai', deleted => sub {
    defined $_[0]->{oai_deleted};
    },
    set_specs_for => sub {
    my $pub = $_[0];

    my $specs;
    push @$specs, $pub->{type}      if $pub->{type};
    push @$specs, $pub->{dini_type} if $pub->{dini_type};

    push @$specs, "ddc:$_" for @{$pub->{ddc}};

    if ($pub->{ec_funded} && $pub->{ec_funded} eq '1') {
        if ($pub->{type} eq 'researchData') {
            push @$specs, "openaire_data";
        }
        else {
            push @$specs, "openaire";
        }
    }

    if (   $pub->{type}
        && is_array_ref($pub->{file})
        && @{$pub->{file}} > 0
        && $pub->{file}->[0]->{open_access}
        && $pub->{file}->[0]->{open_access} eq '1')
    {
        push @$specs, "$pub->{type}Ftxt", "driver", "open_access";
    }

    $specs;
    };

get '/livecitation' => sub {
    my $params = params;
    my $debug = $params->{debug} ? 1 : 0;
    unless (($params->{id} and $params->{style})
        or $params->{info}
        or $params->{styles})
    {
        return "Required parameters are 'id' and 'style'.";
    }

    if ($params->{styles}) {
        return to_json h->config->{citation}->{csl}->{styles};
    }

    my $pub = h->publication->get($params->{id});

    my $response = LibreCat::Citation->new(
        styles => [$params->{style}],
        debug  => $debug
    )->create($pub)->{$params->{style}};

    if ($debug) {
        return to_dumper $response;
    }
    else {
        template "api/livecitation", {citation => $response};
    }
};

1;
