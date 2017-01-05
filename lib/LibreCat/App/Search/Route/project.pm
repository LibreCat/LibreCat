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

get '/project/:id' => sub {
    my $id   = params->{id};
    my $proj = h->project->get($id);

    my $pub = LibreCat->searcher->search('publication',
        {
            q => "project=$id AND status=public",
            limit => 100,
        }
    );
    $proj->{project_publication} = $pub if $pub->{total} > 0;

    template 'project/record', $proj;
};

get '/project' => sub {
    my $p = h->extract_params();

    my $hits = LibreCat->searcher->search('project', $p);
    return template 'project/list', $hits;
};

1;
