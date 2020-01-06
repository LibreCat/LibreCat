package LibreCat::App::Search::Route::person;

=head1 NAME

LibreCat::App::Search::Route::person - handles routes for person sites

=cut

use Catmandu::Sane;
use Dancer qw/:syntax/;
use LibreCat::App::Helper;
use LibreCat qw(searcher);
use URI::Escape;

=head2 GET /person

List persons alphabetically

=cut

get '/person' => sub {
    my $c = params("query")->{browse} // 'a';

    my %search_params = (
        cql   => ["publication_count>0 AND lastname=" . lc $c . "*"],
        sort  => h->config->{default_person_sort},
        start => 0,
        limit => 1000
    );

    h->log->debug("executing user->search: " . to_dumper(\%search_params));

    my $hits = searcher->search('user', \%search_params);

    template 'person/list', $hits;
};

=head2 GET /person/:id_or_alias

Returns a person's profile page, including publications,
research data and author IDs.

=cut

get "/person/:id" => sub {
    my $id = params("route")->{id};

    # Redirect to the alias if the ID cannot be found
    h->log->debug("trying to find user $id");
    my $user = h->main_user->get($id);
    unless ($user) {
        h->log->debug("trying to find user alias $id");

        my %search_params = (cql => ["alias=$id"]);

        my $hits = searcher->search('user', \%search_params);

        if (!$hits->{total}) {
            status '404';
            return template 'error', {message => "No user found with ID $id"};
        }
        else {
            my $person = $hits->first;
            forward "/person/$person->{_id}";
        }
    }

    my $p = h->extract_params();
    $p->{sort} = $p->{sort} // h->config->{default_sort};

    push @{$p->{cql}}, ("person=$id", "status=public");

    $p->{limit} = h->config->{maximum_page_size};

    h->log->debug("executing publication->search: " . to_dumper($p));
    my $hits = searcher->search('publication', $p);

    $p->{limit}    = h->config->{maximum_page_size};
    $hits->{id}    = $id;
    $hits->{modus} = "user";

    my $marked = session 'marked';
    $hits->{marked} = @$marked       if $marked;
    $hits->{style}  = $user->{style} if $user->{style};

    template 'home', $hits;
};

=head2 GET /staffdirectory/:id

Redirects the user to the local staff directory page

=cut

get '/staffdirectory/:id' => sub {
    my $id = params("route")->{id};

    if (h->config->{person} && h->config->{person}->{staffdirectory}) {
        redirect sprintf "%s%s", h->config->{person}->{staffdirectory},
            uri_escape($id);
    }
    else {
        redirect uri_for(sprintf "/person/%s", uri_escape($id));
    }
};

1;
