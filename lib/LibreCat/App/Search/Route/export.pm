package LibreCat::App::Search::Route::export;

=head1 NAME

LibreCat::App::Search::Route::export - handles exports

=cut

use Catmandu::Sane;
use Catmandu qw(export_to_string);
use Catmandu::Util qw(:is);
use Dancer qw/:syntax/;
use LibreCat;
use LibreCat::App::Helper;

=head2 GET /export

Exports data.

=cut

get '/export' => sub {
    my $params = params;

    unless ( is_string( $params->{fmt} ) ) {
        content_type 'json';
        status '406';
        return to_json {error => "Parameter fmt is missing."};
    }

    my $fmt = $params->{fmt};

    my $export_config = h->config->{route}->{exporter}->{publication};

    unless ( is_hash_ref( $export_config->{$fmt} ) ) {
        content_type 'json';
        status '406';
        return to_json {
            error => sprintf("Export format '%s' not supported.", $fmt)
        };
    }

    my $spec = $export_config->{$fmt};

    my $p = h->extract_params();
    $p->{sort} = $p->{sort} // h->config->{default_sort};

    if( is_string( $p->{sort} ) && $p->{sort} eq "false" ) {
        delete $p->{sort};
    }

    h->log->debug("searching for publications:" . Dancer::to_json($p));
    my $hits = LibreCat->searcher->search('publication', $p);

    my $package = $spec->{package};
    my $options = $spec->{options} || {};
    $options->{style}    = $params->{style}    if $params->{style};
    $options->{explinks} = $params->{explinks} if $params->{explinks};

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
};

1;
