package LibreCat::App::Search::Route::publication;

=head1 NAME

LibreCat::App::Search::Route::publication - handling public record routes.

=cut

use Catmandu::Sane;
use Dancer qw/:syntax/;
use LibreCat::App::Helper;

=head2 GET /publication

Redirect legacy routes to /record

=cut

get qr{/publication/*(.*?)} => sub {
    my ($path) = splat;
    my $params = params;

    forward "/record/$path", $params;
};

=head2 GET /record/:id.:fmt

Export normal publication in format :fmt

=cut

get '/record/:id.:fmt' => sub {
    my $id  = params->{id};
    my $fmt = params->{fmt} // 'yaml';

    forward "/export",
        {
        cql => "id=$id",
        fmt => $fmt
        };
};

=head2 GET /record/:id

Splash page for :id.

=cut

get qr{/record/([A-Fa-f0-9-]+)} => sub {
    my ($id) = splat;

    my $p = h->extract_params();

    # frontdoor: do not allow search queries for user
    delete $p->{q};
    delete $p->{cql};

    push @{$p->{cql}}, ("status=public", "id=$id");

    my $hits = LibreCat->searcher->search('publication', $p);

    unless ($hits->{total}) {
        $p->{cql} = [];
        push @{$p->{cql}}, ("status=public", "altid=$id");

        $hits = LibreCat->searcher->search('publication', $p);
        return redirect "/publication/" . $hits->first->{_id}, 301
            if $hits->{total};
    }

    $hits->{total} ? status 200 : status 404;
    template "publication/record", $hits->first;

};

=head2 GET /record

Search API to (data) publications.

=cut

get qr{/record/*} => sub {
    my $p = h->extract_params();

    push @{$p->{cql}}, "status=public";

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
