package LibreCat::App::Search::Route::ajax;

=head1 NAME

LibreCat::App::Search::Route::ajax - handles routes for  asynchronous requests

=cut

use Catmandu::Sane;
use Catmandu::Util qw(join_path :is);
use Dancer qw/:syntax/;
use Dancer::Plugin::Ajax;
use HTML::Entities;
use LibreCat::App::Helper;
use LibreCat qw(searcher);

=head2 AJAX /search_publication

Ajax route for autocomplete feature in forms.

=cut

ajax '/search_publication' => sub {

    my $term = get_term();

    return to_json([]) unless defined($term);

    my $limit = h->config->{default_page_size} // 10;

    my @terms = split_term( $term );
    $terms[-1] .= "*" if @terms;
    my @cql_parts = map {"(basic all \"$_\")"} @terms;

    my $cql_query = join(" AND ", @cql_parts);

    my %search_params = (
        cql_query    => $cql_query,
        limit        => $limit,
        sru_sortkeys => 'title,,1'
    );

    h->log->debug(
        "executing publication->search: " . to_dumper(\%search_params));

    my $hits = h->publication->search(%search_params);

    h->log->debug($hits->total . " hits");

    if ($hits->total) {
        my @map = map {
            my $author = $_->{author}->[0]->{full_name}
                // $_->{editor}->[0]->{full_name}
                // $_->{translator}->[0]->{full_name};
            {
                id    => $_->{_id},
                label => "$author ($_->{year}): $_->{title} [$_->{type}]",
                title => $_->{title},
            };
        } @{$hits->{hits}};

        return to_json \@map;
    }
    else {
        return to_json [];
    }
};

=head2 AJAX /search_researcher

=cut

ajax '/search_researcher' => sub {

    my $term = get_term();

    return to_json([]) unless defined($term);

    my $cql;
    push @$cql, $term;

    my $limit = h->config->{default_page_size} // 10;

    my %search_params = (cql => $cql, limit => $limit,
        sort => h->config->{default_person_sort});
    h->log->debug("executing user->search: " . to_dumper(\%search_params));

    my $hits = searcher->search('user', \%search_params)->{hits};

    return to_json $hits;
};

=head2 AJAX /authority_user/:id

=cut

ajax '/authority_user/:id' => sub {
    my $person = h->get_person(params("route")->{id}) || {error => "No user found."};
    to_json $person;
};

=head2 AJAX /get_alias/:id/:alias

=cut

ajax '/get_alias/:id/:alias' => sub {
    my $rparams = params("route");
    my $term = $rparams->{'alias'};
    my $id = $rparams->{'id'};

    my %search_params = (
        cql_query => "alias=$term AND id<>$id",
        limit => 0
    );
    h->log->debug("executing user->search: " . to_dumper(\%search_params));

    my $hits = h->user()->search(%search_params);

    return to_json {ok => $hits->total ? 0 : 1};
};

=head2 AJAX /get_project

=cut

ajax '/get_project' => sub {

    my $term = get_term();

    return to_json([]) unless defined($term);

    my $limit = h->config->{default_page_size} // 10;

    my @terms = split_term( $term );
    $terms[-1] .= "*" if @terms;
    my @cql_parts = map {"(basic all \"$_\")"} @terms;

    my $cql_query = join(" AND ", @cql_parts);

    my %search_params = (cql_query => $cql_query, limit => $limit,
        sru_sortkeys => 'name,,1');

    h->log->debug("executing project->search: " . to_dumper(\%search_params));

    my $hits = h->project->search(%search_params);

    h->log->debug($hits->total . " hits");

    if ($hits->total) {
        my $map;
        @$map
            = map {{id => $_->{_id}, label => $_->{name}};} @{$hits->{hits}};
        return to_json $map;
    }
    else {
        return to_json [];
    }
};

=head2 AJAX /get_department

=cut

ajax '/get_department' => sub {
    my $term = get_term();

    return to_json([]) unless defined($term);

    my $limit = h->config->{default_page_size} // 10;

    my @terms = split_term( $term );
    $terms[-1] .= "*" if @terms;
    my @cql_parts = map {"(name_lookup all \"$_\")"} @terms;

    my $cql_query = join(" AND ", @cql_parts);

    my %search_params = (
        cql_query    => $cql_query,
        limit        => $limit,
        sru_sortkeys => 'display,,1'
    );

    h->log->debug(
        "executing department->search: " . to_dumper(\%search_params));

    my $hits = h->department->search(%search_params);

    h->log->debug($hits->total . " hits");

    if ($hits->total) {
        my $map;
        @$map = map {{id => $_->{_id}, label => $_->{display}};}
            @{$hits->{hits}};
        return to_json $map;
    }
    else {
        return to_json [];
    }
};

=head2 AJAX /get_research_group

=cut

ajax '/get_research_group' => sub {

    my $term = get_term();

    return to_json([]) unless defined($term);

    my $limit = h->config->{default_page_size} // 10;

    my @terms = split_term( $term );
    $terms[-1] .= "*" if @terms;
    my @cql_parts = map {"(name_lookup all \"$_\")"} @terms;

    my $cql_query = join(" AND ", @cql_parts);

    my %search_params = (cql_query => $cql_query, limit => $limit,
        sru_sortkeys => 'name,,1');

    h->log->debug(
        "executing research_group->search: " . to_dumper(\%search_params));

    my $hits = h->research_group->search(%search_params);

    h->log->debug($hits->total . " hits");

    if ($hits->total) {
        my $map;
        @$map
            = map {{id => $_->{_id}, label => $_->{name}};} @{$hits->{hits}};
        return to_json $map;
    }
    else {
        return to_json [];
    }
};

sub get_term {

    my $qparams = params("query");

    my $term = is_string( $qparams->{term} ) ?
        $qparams->{term} :
        is_array_ref( $qparams->{term} ) ? $qparams->{term}->[0] : "";

    $term =~ s/^\s+//o;
    $term =~ s/\s+$//o;

    length($term) ? $term : undef;

}

sub split_term {
    split( /\s+/o, $_[0] );
}

1;
