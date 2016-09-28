package LibreCat::App::Search::Route::person;

=head1 NAME

LibreCat::App::Search::Route::person - handles routes for person sites

=cut

use Catmandu::Sane;
use Dancer qw/:syntax/;
use LibreCat::App::Helper;

=head2 GET /person

Search person data.

=cut
get qr{/person/*([a-z,A-Z])*} => sub {
    my ($c) = splat;
    $c = $c // 'a';

    my $hits = h->search_researcher({
        q => ["lastname=". lc $c ."*"],
        start => 0,
        limit => 1000,
    });

    my $result;
    @{$hits->{hits}} = map {
        my $rec = $_;
        my $pub = h->search_publication({
            q => ["person=$rec->{_id}"],
            start => 0,
            limit => 1,
        });
        ($pub->{total} > 0) ? $rec : undef;
    } @{$hits->{hits}};

    @{$hits->{hits}} = grep defined, @{$hits->{hits}};

    # override the total number since we deleted some entries
    $hits->{total} = scalar @{$hits->{hits}};
    template 'person/index', $hits;
};

=head2 GET /person/:id

Returns a person's profile page, including publications,
research data and author IDs.

=cut
get qr{/person/(\d+|[a-fA-F\d]{8}(?:-[a-fA-F\d]{4}){3}-[a-fA-F\d]{12})/*(\w+)*/*} => sub {
    my ($id, $modus) = splat;
    my $p = h->extract_params();
    my @orig_q = @{$p->{q}};

    push @{$p->{q}}, ("person=$id", "status=public");

    if ($modus and $modus eq "data") {
        push @{$p->{q}}, "type=research_data";
    }
    else {
        push @{$p->{q}}, "type<>research_data";
    }

    my $sort_style
        = h->get_sort_style($p->{sort} || '', $p->{style} || '', $id);
    $p->{sort}   = $sort_style->{sort};
    $p->{facets} = h->default_facets();
    $p->{limit}  = h->config->{maximum_page_size};

    my $hits = h->search_publication($p);

    unless ($hits->total) {
        $hits = h->search_researcher({q => ["alias=$id"]});
        if (!$hits->{total}) {
            status '404';
            template 'websites/404', {path => request->path};
        }
        else {
            my $person = $hits->first;
            forward "/person/$person->{_id}";
        }
    }

    # search for research hits (only to see if present and to display tab)
    my $researchhits;
    @{$p->{q}} = @orig_q;
    push @{$p->{q}},
        ("type=research_data", "person=$id", "status=public");
    $p->{limit} = 1;

    $hits->{researchhits} = h->search_publication($p);

    $p->{limit}    = h->config->{maximum_page_size};
    $hits->{style} = $sort_style->{style};
    $hits->{sort}  = $p->{sort};
    $hits->{id}    = $id;
    $hits->{modus} = $modus || "user";

    my $marked = session 'marked' // [];
    $hits->{marked} = @$marked;

    template 'home', $hits;

};

1;
