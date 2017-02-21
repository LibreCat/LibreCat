package LibreCat::App::Api::Route::LiveCitation;

=head1 NAME

LibreCat::App::Catalogue::Route::LiveCitation - Test the CSL engine

=cut

use Catmandu::Sane;
use Dancer ':syntax';
use Dancer::Plugin::Auth::Tiny;
use LibreCat::App::Helper;
use LibreCat::Citation;

get '/livecitation' => sub {
    my $params = params;
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
    )->create($pub);
return to_dumper $response;
    my $citation = $response ? $response->{$params->{style}} : undef;

    if (!defined $citation) {
        content_type 'application/json';
        return to_json { error => 'Null response from citation generator'};
    }
    else {
        template "api/livecitation", {citation => $response->{$params->{style}}};
    }
};
