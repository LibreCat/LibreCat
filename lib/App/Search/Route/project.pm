package App::Search::Route::project;

=head1 NAME

  App::Search::Route::project - handling routes for project pages.

=cut

use Catmandu::Sane;
use Dancer qw/:syntax/;
use App::Helper;

=head2 GET /project/:id

Project splash page for :id.

=cut
get qr{/project/(P\d+)/*} => sub {
    my ($id) = splat;
    my $proj = h->project->get($id);

    my $pub = h->publication->search(cql_query => "project=$id", limit => 100);
    $proj->{project_publication} = $pub;

    template 'project/project', $proj;
};

1;
