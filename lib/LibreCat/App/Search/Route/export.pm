package LibreCat::App::Search::Route::export;

=head1 NAME

LibreCat::App::Search::Route::export - handles exports

=cut

use Catmandu::Sane;
use Catmandu qw(export_to_string);
use Dancer qw/:syntax/;
use LibreCat;
use LibreCat::App::Helper;

=head2 GET /publication/:id.:fmt

Exports data.

=cut
get '/publication/:id.:fmt' => sub {
    my $id  = params->{id};
    my $fmt = params->{fmt} // 'yaml';

    forward "/export",
        {cql => "id=$id", bag => $bag, fmt => params->{fmt}};
};

=head2 GET /export

Exports data.

=cut
get '/export' => sub {

    unless (params->{bag} && params->{fmt}) {
        content_type 'json';
        status '406';
        return to_json {error => "Parameters bag or fmt are missing."};
    }

    my $bag = params->{bag} eq 'data' ? 'publication' : params->{bag};
    my $fmt = params->{fmt};

    my $export_config = LibreCat->config->{exporter}->{$bag};

    unless ($export_config->{$fmt}) {
        content_type 'json';
        status '406';
        return to_json {error => sprintf("Export format '%s' not supported for entity '%s'.", $fmt, $bag)};
    }

    my $spec = $export_config->{$fmt};

    my $p = h->extract_params();

    my $hits = LibreCat->searcher->search('publication', $p);

    my $package = $spec->{package};
    my $options = $spec->{options} || {};
    $options->{style}    = params->{style};
    $options->{explinks} = params->{explinks};

    my $content_type = $spec->{content_type} || mime->for_name($fmt);
    my $extension    = $spec->{extension} || $fmt;

    my $f = export_to_string($hits, $package, $options);

    return Dancer::send_file(
        \$f,
        content_type => $content_type,
        filename     => "$bag.$extension"
    );
};

1;
