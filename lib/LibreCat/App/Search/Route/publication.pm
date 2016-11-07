package LibreCat::App::Search::Route::publication;

=head1 NAME

LibreCat::App::Search::Route::publication - handling public record routes.

=cut

use Catmandu::Sane;
use Dancer qw/:syntax/;
use LibreCat::App::Helper;

=head2 GET /{data|publication}/:id

Splash page for :id.

=cut

get qr{/(data|publication)/(\d{1,})/*} => sub {
    my ($bag, $id) = splat;

    my $p = h->extract_params();
    my $altid;
    push @{$p->{q}}, ("status=public", "id=$id");
    push @{$p->{q}},
        ($bag eq 'data') ? "type=research_data" : "type<>research_data";

    my $hits = LibreCat->searcher->search('publication', $p);


    if (!$hits->{total}) {
        $p->{q} = [];
        push @{$p->{q}}, ("status=public", "altid=$id");
        push @{$p->{q}},
            ($bag eq 'data') ? "type=research_data" : "type<>research_data";
        $hits = LibreCat->searcher->search('publication', $p);
        return redirect "$bag/$hits->first->{_id}", 301 if $hits->{total};
    }

    #$hits->{bag} = $bag;

    #$hits->{hits}->[0]->{marked} = session 'marked' // [];

    #if ($p->{fmt} ne 'html') {
    #    h->export_publication($hits, $p->{fmt});
    #}
    #else {
    #return redirect "$bag/$hits->first->{_id}", 301 if $altid;
    #$hits->{hits}->[0]->{bag} = $bag;
    $hits->{total} ? status 200 : status 404;
    template "publication/record", $hits->first;

    #}
};

=head2 GET /{data|publication}

Search API to (data) publications.

=cut

get qr{/(data|publication)/*} => sub {
    my ($bag) = splat;
    my $p = h->extract_params();
    #$p->{facets} = h->default_facets();
    my $sort_style = h->get_sort_style($p->{sort} || '', $p->{style} || '');
    $p->{sort} = $sort_style->{sort};

    ($bag eq 'data')
        ? push @{$p->{q}}, ("status=public", "type=research_data")
        : push @{$p->{q}}, ("status=public", "type<>research_data");

    my $hits = LibreCat->searcher->search('publication', $p);

    $hits->{style}         = $sort_style->{style};
    $hits->{sort}          = $p->{sort};
    $hits->{user_settings} = $sort_style;

   #if ($p->{fmt} ne 'html') {
   #    h->export_publication($hits, $p->{fmt});
   #}
   #elsif ($p->{embed} or ($p->{ftyp} and $p->{ftyp} eq "iframe")) {
   #    my $lang = $p->{lang} || session->{lang} || h->config->{default_lang};
   #    $hits->{lang}  = $lang;
   #    $hits->{embed} = 1;
   #    template "iframe", $hits;
   #}
   #else {
   #my $template = 'publication/list';
   #if ($p->{ftyp} and $p->{ftyp} =~ /js/) {
   #$template .= "_" . $p->{ftyp};
   #$template .= "_num" if ($p->{enum} and $p->{enum} eq "1");
   #$template .= "_numasc" if ($p->{enum} and $p->{enum} eq "2");
   #header("Content-Type" => "text/plain")
   #}
    template 'publication/list', $hits;

    #}
};

=head2 GET /{data|publication}/embed

Embed API to (data) publications

=cut

get qr{/(data|publication)/embed/*} => sub {
    my ($bag) = splat;

    my $p = params;
    $p->{embed} = 1;
    forward "/$bag", $p;
};

get qr{/embed/*} => sub {
    my $p = h->extract_params();
    my $portal = h->config->{portal}->{$p->{ttyp}} if $p->{ttyp};
    my $pq;

    if ($portal) {
        $pq = h->is_portal_default($p->{ttyp});
        $p  = $pq->{full_query};
    }
    push @{$p->{q}}, ("status=public");
    #$p->{facets} = h->default_facets();

    # override default facets
    $p->{facets}->{author}->{terms}->{size} = 100;
    $p->{facets}->{editor}->{terms}->{size} = 100;

    my $sort_style = h->get_sort_style(
        params->{sort}  || $pq->{default_query}->{'sort'} || '',
        params->{style} || $pq->{default_query}->{style}  || ''
    );

    $p->{sort}  = $sort_style->{sort};
    $p->{start} = params->{start};
    my $hits = LibreCat->searcher->search('publication', $p);
    $hits->{bag}   = "publication";
    $hits->{embed} = 1;
    $hits->{ttyp}  = $p->{ttyp} if $p->{ttyp};
    $hits->{style} = $sort_style->{style};

    my $lang = $p->{lang} || session->{lang} || h->config->{default_lang};
    $hits->{lang} = $lang;
    template "iframe", $hits;
};

1;
