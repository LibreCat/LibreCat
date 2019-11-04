package LibreCat::Controller::SearchApi;

use Catmandu::Sane;
use Catmandu::Util qw(:is);
use LibreCat -self;
use Mojo::Base "Mojolicious::Controller";

sub search {
    my $c     = $_[0];
    my $model = $c->param('model');

    my $recs = librecat->model($model);

    my $hits = librecat->searcher->search(
        $model,
        {
            q     => $c->param('q'),
            cql   => $c->param('cql'),
            start => $c->param('start'),
            limit => $c->param('limit'),
            sort  => $c->param('sort'),
        }
    );

    my $pagination;
    foreach (qw(next_page last_page page previous_page pages_in_spread)) {
        $pagination->{$_} = $hits->$_;
    }

    my $data = {
        type       => $model,
        query      => {q => $c->param('q'), cql => $c->param('cql')},
        count      => $hits->total,
        attributes => {
            hits       => $hits->to_array,
            aggs       => $hits->{aggregations},
            pagination => $pagination
        },
        links => {self => $c->url_for->to_abs,},
    };

    $c->render(json => {data => $data});
}

1;

__END__

=pod

=head1 NAME

LibreCat::Controller::SearchApi - a model-specific search controller used by L<Mojolicious::Plugin::LibreCat::Api>

=head2 SEE ALSO

L<LibreCat>, L<Mojolicious::Plugin::LibreCat::Api>

=cut
