package LibreCat::App::Search::Route::publication;

=head1 NAME

LibreCat::App::Search::Route::publication - handling public record routes.

=cut

use Catmandu::Sane;
use Catmandu qw(export_to_string);
use Clone qw(clone);
use Dancer qw/:syntax/;
use LibreCat::App::Helper;
use LibreCat qw(searcher);

=head2 GET /record/:id.:fmt

Export publication with ID :id in format :fmt

=cut

get '/record/:id.:fmt' => sub {
    my $id  = params->{id};
    my $fmt = params->{fmt} // 'yaml';

    forward "/export", {cql => "id=$id", fmt => $fmt};
};

=head2 GET /record/:id

Splash page for :id.

=cut

state $jsonld_fix = h->create_fixer('fixes/to_json_ld.fix');

get "/record/:id" => sub {
    my $id = params("route")->{id};

    my $p = +{
        cql => [ "status=public", "id=$id" ],
        limit => 1
    };

    my $hits = searcher->search('publication', $p);

    unless ($hits->{total}) {
        $p->{cql} = [];
        push @{$p->{cql}}, ("status=public", "altid=$id");

        $hits = searcher->search('publication', $p);
        return redirect "/record/" . $hits->first->{_id}, 301
            if $hits->{total};
    }

    $hits->{total} ? status 200 : status 404;

    my $d = clone($hits->first);
    if ($hits->{total}) {
        $hits->{hits}->[0]->{schema_org} = export_to_string($d, 'JSON', {line_delimited => 1, fix => $jsonld_fix});
    }

    template "publication/record", $hits->first;

};

=head2 GET /record

Search API to (data) publications.

=cut

get qr{/record/*} => sub {
    my $p = h->extract_params();

    push @{$p->{cql}}, "status=public";

    $p->{sort} = $p->{sort} // h->config->{default_sort};

    my $hits = searcher->search('publication', $p);

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

    my $hits = searcher->search('publication', $p);

    $hits->{embed} = 1;

    my $lang = h->locale_exists( $p->{lang} ) ? $p->{lang} : h->locale();
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
