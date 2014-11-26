package App::Search::Route::unapi;

use Catmandu::Sane;
use Catmandu;
use Dancer qw(:syntax);
use App::Helper;

get '/unapi' => sub {
    my $id = params->{id};
    my $format = params->{format};

    if ($id && $format) {
        return forward "/publication/$id", {fmt => $format};
    }

    content_type 'xml';

    my $specs = $id && h->config->{exporter}->{publication};
    my $out = qq(<?xml version="1.0" encoding="UTF-8" ?>\n);

    if ($id) {
        $out .= qq(<formats id="$id">);
    } else {
        $out .= qq(<formats>);
    }

    for my $fmt (keys %$specs) {
        my $content_type = $specs->{fmt}->{content_type} || mime->for_name($specs->{fmt}->{extension});
        $out .= qq(<format name="$fmt" type="$content_type"/>);
    }

    $out . qq(</formats>);

};

1;
