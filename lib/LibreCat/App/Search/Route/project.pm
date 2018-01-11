package LibreCat::App::Search::Route::project;

=head1 NAME

LibreCat::App::Search::Route::project - handling routes for project pages.

=cut

use Catmandu::Sane;
use Dancer qw/:syntax/;
use LibreCat::App::Helper;

=head2 GET /project/:id

Project splash page for :id.

=cut

get qr{/project/([a-zA-Z0-9].*)} => sub {
    my ($id) = splat;
    my $proj = h->project->get($id);

    my $pub = LibreCat->searcher->search('publication',
        {cql => ["project=$id", "status=public"], limit => 100});
    $proj->{project_publication} = $pub if $pub->{total} > 0;

    template 'project/record', $proj;
};

=head2 GET /project

Project page with alphabetical browsing.

=cut

get qr{/project/*} => sub {
    my $c = params->{browse} // 'a';
    my %search_params
        = (query => {prefix => {'name.exact' => lc($c)}}, sru_sortkeys => "name,,1", limit => 1000);

    h->log->debug(
        "executing project->native_search: " . to_dumper(\%search_params));

    my $hits = LibreCat->searcher->native_search('project', \%search_params);

    template 'project/list', $hits;
};

1;
