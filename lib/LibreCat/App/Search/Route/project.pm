package LibreCat::App::Search::Route::project;

=head1 NAME

LibreCat::App::Search::Route::project - handling routes for project pages.

=cut

use Catmandu::Sane;
use Dancer qw/:syntax/;
use LibreCat::App::Helper;
use LibreCat qw(searcher);

=head2 GET /project/:id

Project splash page for :id.

=cut

my $route_project = sub {
    my $id = params("route")->{id};
    my $proj = h->project->get($id);

    my $pub = searcher->search('publication',
        {cql => ["project=$id", "status=public"], limit => 100});
    $proj->{project_publication} = $pub if $pub->{total} > 0;

    template 'project/record', $proj;
};

get "/project/:id" => $route_project;
get "/project/:id/" => $route_project;

=head2 GET /project

Project page with alphabetical browsing.

=cut

get "/project" => sub {
    my $browse             = param("browse") // 'a';
    my %search_params = (
        query        => {prefix => {'name.exact' => lc($browse)}},
        sru_sortkeys => "name,,1",
        limit        => 1000
    );

    h->log->debug(
        "executing project->native_search: " . to_dumper(\%search_params));

    my $hits = searcher->native_search('project', \%search_params);

    template 'project/list', $hits;
};

1;
