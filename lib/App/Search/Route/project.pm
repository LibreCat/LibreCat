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

    my $pub = h->search_publication(q => "project=$id", limit => 100)

    template 'project', {data => $proj, publhits => $pub};
};

1;
