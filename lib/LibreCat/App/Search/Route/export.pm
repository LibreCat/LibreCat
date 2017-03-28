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

    forward "/export", {cql => "id=$id", bag => 'publication', fmt => $fmt};
};

=head2 GET /export

Exports data.

=cut
get '/export' => sub {
    unless (params->{fmt}) {
        content_type 'json';
        status '406';
        return to_json {error => "Parameter fmt is missing."};
    }

    my $fmt = params->{fmt};

    my $export_config = h->config->{exporter}->{'publication'};

    unless ($export_config->{$fmt}) {
        content_type 'json';
        status '406';
        return to_json {error => sprintf("Export format '%s' not supported.", $fmt)};
    }

    my $spec = $export_config->{$fmt};

    my $p = h->extract_params();
    $p->{sort} = $p->{sort} // h->config->{default_sort};

    if (request->referer =~ /\/publication/) {
        push @{$p->{cql}}, "type<>research_data";
    }
    elsif (request->referer =~ /\/data/) {
        push @{$p->{cql}}, "type=research_data";
    }
    elsif (request->referer =~ /\/marked$/) {
        my $marked = session 'marked';
        $p->{cql} = ["(id=" . join(' OR id=', @$marked) . ")"];
        delete $p->{sort};
    }

    h->log->debug("searching for publications:" . Dancer::to_json($p));
    my $hits = LibreCat->searcher->search('publication', $p);

    my $package = $spec->{package};
    my $options = $spec->{options} || {};
    $options->{style}    = params->{style} if params->{style};
    $options->{explinks} = params->{explinks} if params->{explinks};

    my $content_type = $spec->{content_type} || mime->for_name($fmt);
    my $extension    = $spec->{extension} || $fmt;

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
