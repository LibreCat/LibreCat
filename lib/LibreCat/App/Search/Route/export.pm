package LibreCat::App::Search::Route::export;

=head1 NAME

LibreCat::App::Search::Route::export - export route handlers

=cut

use Catmandu::Sane;
use Catmandu qw(export_to_string);
use Catmandu::Util qw(:is);
use Dancer qw/:syntax/;
use Clone qw(clone);
use LibreCat;
use LibreCat::App::Helper;
use Encode qw();

sub _export {
    my $params = shift;

    my $export_config = h->config->{route}->{exporter};

    # Only consider a these params
    my $fmt   = $params->{fmt};
    my $cql   = $params->{cql};
    my $q     = $params->{q};
    my $start = $params->{start} // 0;
    my $limit = $params->{limit};
    my $sort  = $params->{sort};

    $sort  = h->config->{default_sort} unless $sort;

    unless (is_string($fmt)) {
        content_type 'application/json';
        status '406';
        return to_json {error => "Parameter fmt is missing."};
    }

    unless (is_hash_ref($export_config->{publication}->{$fmt})) {
        content_type 'application/json';
        status '406';
        return to_json {error => "Export format '$fmt' not supported."};
    }

    my $query_params = {
        cql   => $cql   ,
        q     => $q     ,
        start => $start ,
        limit => $limit ,
        sort  => $sort  ,
    };

    h->log->debug("searching for publications:" . Dancer::to_json($query_params));

    my $hits = LibreCat->searcher->search('publication', $query_params);

    # We are changing the configurate options inline
    # A clone is required to work on a local version of these options
    my $spec    = $export_config->{publication}->{$fmt};
    my $package = $spec->{package};
    my $options = clone($spec->{options}) || {};

    # Adding csl specific parameters via URL?
    my $current_style = h->current_style;
    $options->{style} = $current_style if $current_style;
    $options->{links} = $params->{links} // 0;

    h->log->debug("exporting $package:" . Dancer::to_json($options));

    my $f;

    eval {
        # Explicitly use the Helper (LibreCat) fixer
        my $fixes = $options->{fix} // ["nothing()"];
        delete $options->{fix};
        my $fixer = h->create_fixer($fixes);
        $f = export_to_string($fixer->fix($hits), $package, $options);
    };
    if ($@) {
        h->log->error("exporting $package: $@");
        content_type 'application/json';
        status '500';
        return to_json {
            error => "Export $fmt failed: $@"
        };
    }
    else {
        my $content_type = $spec->{content_type} || mime->for_name($fmt);
        my $charset = $spec->{charset} // "utf-8";
        $content_type = "$content_type;charset=$charset";
        my %headers   = (
            "Content-Type" => $content_type
        );

        if ($spec->{extension}) {
            $headers{"Content-Disposition"} = "inline;filename=publication.".$spec->{extension};
        }

        h->log->trace($f);
        $f = Encode::encode( $charset, $f );
        $headers{"Content-Length"} = length($f);

        #override weird Dancer reencoding behaviour
        Dancer::Response->new(
            status => 200,
            content => $f,
            encoded => 1,
            headers => [%headers],
            forward => ""
        );
    }
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
    push @{$params->{cql}}, "status<>deleted";
    return _export($params);
};

1;
