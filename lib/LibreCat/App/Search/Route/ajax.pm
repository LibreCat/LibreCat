package LibreCat::App::Search::Route::ajax;

=head1 NAME

LibreCat::App::Search::Route::ajax - handles routes for  asynchronous requests

=cut

use Catmandu::Sane;
use Catmandu::Util qw(join_path);
use Dancer qw/:syntax/;
use Dancer::Plugin::Ajax;
use HTML::Entities;
use LibreCat::App::Helper;

=head2 AJAX /metrics/:id

Web of Science 'Times Cited' information

=cut

ajax '/metrics/:id' => sub {
    my $metrics = h->get_metrics('wos', params->{id});
    return to_json {
        times_cited => $metrics->{times_cited},
        citing_url  => $metrics->{citing_url},
    };
};

ajax '/bibtex/:id' => sub {
    my $pub = h->publication->get(params->{id});
    return to_json {
        bibtex => encode_entities(h->export_publication($pub, 'bibtex', 1)),
    };
};

ajax '/ris/:id' => sub {
    my $pub = h->publication->get(params->{id});
    my $ris = h->export_publication($pub, 'ris', 1);
    utf8::decode($ris);
    return to_json {ris => encode_entities($ris),};
};

=head2 AJAX /search_researcher

=cut

ajax '/search_researcher' => sub {
    my $q;
    push @$q, params->{'term'};

    my %search_params = (q => $q, limit => 100 , sort => 'fullname.asc');
    h->log->debug("executing researcher->search: " . to_dumper(\%search_params));

    my $hits = LibreCat->searcher->search('researcher', \%search_params)->{hits};

    return to_json $hits;
};

=head2 AJAX /get_person
=cut

ajax '/authority_user/:id' => sub {
    my $person = h->get_person(params->{id}) || {error => "No user found."};
    to_json $person;
};

ajax '/num_of_publ/:id' => sub {
    my $id = params->{id};

    my %search_params = (q => ["person=$id"]);
    h->log->debug("executing publication->search: " . to_dumper(\%search_params));

    my $hits = LibreCat->searcher->search('publication', \%search_params);

    return to_json {total => $hits->{total}};
};

=head2 AJAX /get_alias/:id/:alias

=cut

ajax '/get_alias/:id/:alias' => sub {
    my $term = params->{'alias'} || "";
    my $id   = params->{'id'};

    my %search_params = (q => ["alias=$term", "id<>$id"]);
    h->log->debug("executing researcher->search: " . to_dumper(\%search_params));

    my $hits = LibreCat->searcher->search('researcher', \%search_params);

    return to_json {ok => $hits->{total} ? 0 : 1};
};

=head2 AJAX /get_project

=cut

ajax '/get_project' => sub {
    my $limit = length(params->{term}) ? 10 : 1000;
    my @q = map { $_ . "*" } split(' ', params->{term});

    my %search_params = (q => \@q, limit => $limit, sort => 'name.asc');
    h->log->debug("executing project->search: " . to_dumper(\%search_params));

    my $hits = LibreCat->searcher->search('project', \%search_params);

    if ($hits->{total}) {
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
    my $limit = length(params->{term}) ? 10 : 1000;
    my @q     = map { $_ . "*" } split(' ', params->{term});
    push @q, "inactive<>1";

    my %search_params = (q => \@q, limit => $limit, sort => 'display.asc');
    h->log->debug("executing department->search: " . to_dumper(\%search_params));

    my $hits = LibreCat->searcher->search('department', \%search_params);

    if ($hits->{total}) {
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
    my $limit = length(params->{term}) ? 10 : 1000;
    my @q = map { $_ . "*" } split(' ', params->{term});

    my %search_params = (q => \@q, limit => $limit, sort => 'name.asc');
    h->log->debug("executing research_group->search: " . to_dumper(\%search_params));

    my $hits = LibreCat->searcher->search('research_group', \%search_params);

    if ($hits->{total}) {
        my $map;
        @$map
            = map {{id => $_->{_id}, label => $_->{name}};} @{$hits->{hits}};
        return to_json $map;
    }
    else {
        return to_json [];
    }
};

1;
