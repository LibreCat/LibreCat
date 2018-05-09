package LibreCat::App::Search::Route::export;

=head1 NAME

LibreCat::App::Search::Route::export - export route handlers

=cut

use Catmandu::Sane;
use Catmandu qw(export_to_string);
use Catmandu::Util qw(:is);
use Dancer qw/:syntax/;
use LibreCat qw(searcher);
use LibreCat::App::Helper;

sub _export {
    my $params = shift;

    unless (is_string($params->{fmt})) {
        content_type 'json';
        status '406';
        return to_json {error => "Parameter fmt is missing."};
    }

    my $fmt = $params->{fmt};

    state $export_config = h->config->{route}->{exporter}->{publication};

    unless (is_hash_ref($export_config->{$fmt})) {
        content_type 'json';
        status '406';
        return to_json {
            error => sprintf("Export format '%s' not supported.", $fmt)
        };
    }

    my $spec = $export_config->{$fmt};

    h->log->debug("searching for publications:" . Dancer::to_json($params));
    my $hits = searcher->search('publication', $params);

    unless ($hits->total > 0 ){
        status '404';
        return;
    }

    my $package = $spec->{package};
    my $options = $spec->{options} || {};
    $options->{style} = $params->{style} if $params->{style};
    $options->{links} = $params->{links} // 0;

    my $content_type = $spec->{content_type} || mime->for_name($fmt);
    my $extension    = $spec->{extension}    || $fmt;

    h->log->debug("exporting $package:" . Dancer::to_json($options));
    my $f = export_to_string($hits, $package, $options);

    h->log->debug($f);
    return Dancer::send_file(
        \$f,
        content_type => $content_type,
        filename     => "publication.$extension"
    );
}

=head2 GET /export

Exports data, public only!

=cut
get '/export' => sub {
    my $params = h->extract_params;
    push @{$params->{cql}}, "status=public";
    return _export($params);
};

=head2 GET /librecat/export

Exports data from the logged-in-area.

=cut
get '/librecat/export' => sub {
    my $params = h->extract_params;
    return _export($params);
};
1;
