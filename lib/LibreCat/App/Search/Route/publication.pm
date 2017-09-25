package LibreCat::App::Search::Route::publication;

=head1 NAME

LibreCat::App::Search::Route::publication - handling public record routes.

=cut

use Catmandu::Sane;
use Dancer qw/:syntax/;
use LibreCat::App::Helper;

=head2 GET /publication/:id.:fmt

Export normal publication in format :fmt

=cut

get '/publication/:id.:fmt' => sub {
    my $id = params->{id};
    my $fmt = params->{fmt} // 'yaml';

    forward "/export",
        {
        cql => "(id=$id AND type<>research_data)",
        bag => 'publication',
        fmt => $fmt
        };
};

=head2 GET /data/:id.:fmt

Export data publication in format :fmt

=cut

get '/data/:id.:fmt' => sub {
    my $id = params->{id};
    my $fmt = params->{fmt} // 'yaml';

    forward "/export",
        {
        cql => "(id=$id AND type=research_data)",
        bag => 'publication',
        fmt => $fmt
        };
};

=head2 GET /{data|publication}/:id

Splash page for :id.

=cut

get qr{/(data|publication)/([A-Fa-f0-9-]+)} => sub {
    my ($bag, $id) = splat;

    my $p = h->extract_params();

    # frontdoor: do not allow search queries for user
    delete $p->{q};
    delete $p->{cql};

    push @{$p->{cql}}, ("status=public", "id=$id");
    push @{$p->{cql}},
        ($bag eq 'data') ? "type=research_data" : "type<>research_data";

    my $hits = LibreCat->searcher->search('publication', $p);

    unless ($hits->{total}) {
        $p->{cql} = [];
        push @{$p->{cql}}, ("status=public", "altid=$id");
        push @{$p->{cql}},
            ($bag eq 'data') ? "type=research_data" : "type<>research_data";
        $hits = LibreCat->searcher->search('publication', $p);
        return redirect "/" . $bag . "/" . $hits->first->{_id}, 301
            if $hits->{total};
    }

    $hits->{total} ? status 200 : status 404;
    template "publication/record", $hits->first;

};

=head2 GET /{data|publication}

Search API to (data) publications.

=cut

get qr{/(data|publication)/*} => sub {
    my ($bag) = splat;

    my $p = h->extract_params();

    ($bag eq 'data')
        ? push @{$p->{cql}}, ("status=public", "type=research_data")
        : push @{$p->{cql}}, ("status=public", "type<>research_data");

    $p->{sort} = $p->{sort} // h->config->{default_sort};

    my $hits = LibreCat->searcher->search('publication', $p);

    template 'publication/list', $hits;

};

=head2 GET /embed

Embed API to (data) publications

=cut

get '/embed' => sub {
    my $p = h->extract_params();

    push @{$p->{cql}}, ("status=public");

    $p->{sort}  = $p->{sort} // h->config->{default_sort};
    $p->{start} = params->{start};
    $p->{limit} = h->config->{maximum_page_size};

    my $hits = LibreCat->searcher->search('publication', $p);

    $hits->{bag}   = "publication";
    $hits->{embed} = 1;

    my $lang = $p->{lang} || session->{lang} || h->config->{default_lang};
    $hits->{lang} = $lang;

    if (params->{fmt} && params->{fmt} eq 'js') {
        header("Content-Type" => "application/javascript");
        template 'embed/javascript', $hits;
    }
    else {
        template 'embed/iframe', $hits;
    }
};

1;
