package LibreCat::App::Search::Route::person;

=head1 NAME

LibreCat::App::Search::Route::person - handles routes for person sites

=cut

use Catmandu::Sane;
use Dancer qw/:syntax/;
use LibreCat::App::Helper;
use URI::Escape;

=head2 GET /person

List persons alphabetically

=cut

get qr{/person} => sub {
    my $c = params->{browse} // 'a';

    my %search_params = (
        cql   => ["lastname=" . lc $c . "*"],
        sort  => h->config->{default_person_sort},
        start => 0,
        limit => 1000
    );

    h->log->debug("executing user->search: " . to_dumper(\%search_params));

    my $hits = LibreCat->searcher->search('user', \%search_params);

    @{$hits->{hits}} = map {
        my $rec = $_;
        my $pub = LibreCat->searcher->search('publication',
            {cql => ["person=$rec->{_id}"], start => 0, limit => 1,});
        ($pub->{total} > 0) ? $rec : undef;
    } @{$hits->{hits}};

    @{$hits->{hits}} = grep defined, @{$hits->{hits}};

    # override the total number since we deleted some entries
    $hits->{total} = scalar @{$hits->{hits}};

    template 'person/list', $hits;
};

=head2 GET /person/:id_or_alias{/data}

Returns a person's profile page, including publications,
research data and author IDs.

=cut

get qr{/person/(.*?)/?(data)*} => sub {
    my ($id, $modus) = splat;

    # Redirect to the alias if the other can't be found
    h->log->debug("trying to find user $id");
    unless (my $user = Catmandu->store('main')->bag('user')->get($id)) {
        h->log->debug("trying to find user alias $id");

        my %search_params = (cql => ["alias=$id"]);

        my $hits = LibreCat->searcher->search('user', \%search_params);

        if (!$hits->{total}) {
            status '404';
            return template 'error',
                {message => "No user found found with ID $id"};
        }
        else {
            my $person = $hits->first;
            forward "/person/$person->{_id}";
        }
    }

    my $p = h->extract_params();
    $p->{sort} = $p->{sort} // h->config->{default_sort};

    push @{$p->{cql}}, ("person=$id", "status=public");

    if ($modus and $modus eq "data") {
        push @{$p->{cql}}, "type=research_data";
    }
    else {
        push @{$p->{cql}}, "type<>research_data";
    }

    $p->{limit} = h->config->{maximum_page_size};

    h->log->debug("executing publication->search: " . to_dumper($p));
    my $hits = LibreCat->searcher->search('publication', $p);

    # search for research hits (only to see if present and to display tab)
    my $r;
    push @{$r->{cql}}, ("type=research_data", "person=$id", "status=public");
    $r->{limit} = 1;

    h->log->debug("executing publication->search: " . to_dumper($r));
    $hits->{researchhits} = LibreCat->searcher->search('publication', $r);

    $p->{limit}    = h->config->{maximum_page_size};
    $hits->{id}    = $id;
    $hits->{modus} = $modus || "user";

    my $marked = session 'marked';
    $hits->{marked} = @$marked if $marked;

    template 'home', $hits;
};

=head2 GET /staffdirectory/:id

Redirects the user to the local staff directory page

=cut

get '/staffdirectory/:id' => sub {
    my $id = param('id');

    if (h->config->{person} && h->config->{person}->{staffdirectory}) {
        redirect sprintf "%s%s", h->config->{person}->{staffdirectory},
            uri_escape($id);
    }
    else {
        redirect uri_for(sprintf "/person/%s", uri_escape($id));
    }
};

1;
