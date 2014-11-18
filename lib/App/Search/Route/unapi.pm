package App::Search::Route::unapi;

use Catmandu::Sane;
use Catmandu;
use Dancer qw(:syntax);

get '/unapi' => sub {
    my $id = params->{id};
    my $format = params->{format};

    if ($id && $format) {
        return forward "/publication/$id", {format => $format};
    }

    content_type 'xml';

    my $specs = $id ? Catmandu->config->{export_publication} : Catmandu->config->{export_publication_hits};
    my $out = qq(<?xml version="1.0" encoding="UTF-8" ?>\n);

    if ($id) {
        $out .= qq(<formats id="$id">);
    } else {
        $out .= qq(<formats>);
    }

    for my $spec (@$specs) {
        my $content_type = $spec->{content_type} || mime->for_name($spec->{extension} // $spec->{format});
        $out .= qq(<format name="$spec->{format}" type="$content_type"/>);
    }

    $out . qq(</formats>);

};

1;
