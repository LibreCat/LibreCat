package LibreCat::App::Search::Route::livecitation;

=head1 NAME

LibreCat::App::Search::Route::livecitation - test the CSL engine

=cut

use Catmandu::Sane;
use Dancer ':syntax';
use LibreCat -self;
use LibreCat::Citation;

get '/livecitation' => sub {

    if (Dancer::config->{environment} eq 'deployment') {
        status 'not_found';
        return template '404';
    }

    my $params = params;
    unless (($params->{id} and $params->{style}) or $params->{info}) {
        return "Required parameters are 'id' and 'style'.";
    }

    if ($params->{info}) {
        return to_json h->config->{citation}->{csl}->{styles};
    }

    my $pub = Catmandu->store('main')->bag('publication')->get($params->{id});

    my $response
        = LibreCat::Citation->new(style => $params->{style})->create($pub);

    my $citation = $response ? $response->{$params->{style}} : undef;

    if (!defined $citation) {
        content_type 'application/json';
        return to_json {error => 'Null response from citation generator'};
    }
    else {
        template "api/livecitation",
            {citation => $response->{$params->{style}}};
    }
};

1;
