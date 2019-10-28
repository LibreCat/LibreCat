package LibreCat::Controller::SearchApi;

use Catmandu::Sane;
use Catmandu::Util qw(:is);
use LibreCat -self;
use Mojo::Base "Mojolicious::Controller";

sub search {
    my $c     = $_[0];
    my $model = $c->param('model');
    my $query = $c->param('cql');

    # my $aggs = $c->param('aggs') ;
    my $recs = librecat->model($model) // return $c->not_found;

    my $hits = librecat->searcher->search(
        $model,
        {
            q     => [$query],
            start => $c->param('start'),
            limit => $c->param('limit'),
        }
    );

    my $data = {
        type  => $model,
        query => $query,
        count => $hits->total // 0,
        attributes =>
            {hits => $hits->to_array, aggs => $hits->{aggregations},},
        links => {self => $c->url_for->to_abs,},
    };

    $c->render(json => {data => $data});
}

# this one is never reached !
sub not_found {
    my $c     = $_[0];
    my $model = $c->param('model');
    my $error = {status => '404', title => "$model not found",};
    $c->render(json => {errors => [$error]}, status => 404);
}

1;

__END__

=pod

=head1 NAME

LibreCat::Controller::SearchApi - a model-specific search controller used by L<Mojolicious::Plugin::LibreCat::Api>

=head1 SYNOPSIS

=head2 SEE ALSO

L<LibreCat>, L<Mojolicious::Plugin::LibreCat::Api>

=cut
