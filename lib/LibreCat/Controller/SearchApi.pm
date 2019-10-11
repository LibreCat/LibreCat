package LibreCat::Controller::SearchApi;

use Catmandu::Sane;
use Catmandu::Util qw(:is);
use LibreCat -self;
use Mojo::Base "Mojolicious::Controller";
use IO::Handle::Util;
use IO::File;
use URI::Escape qw(uri_escape_utf8);

sub search {
    my $c     = $_[0];
    my $model = $c->param('model');
    my $query    = $c->param('cql');
    my $recs  = librecat->model($model) // return $c->not_found;

    my $hits = librecat->searcher->search($model, {
            # cql_query => ,
            # ...
        }
    );

    my $data = {
        type => $model,
        query => $query,
        count => $hits->total // 0,
        attributes => {
            hits => $hits->to_array,
        },
        links => {self => $c->url_for->to_abs,},
    }

    $c->render(json => {data => $data});
}

sub not_found {
    my $c     = $_[0];
    my $model = $c->param('model');
    my $error = {
        status => '404',
        title  => "$model not found",
    };
    $c->render(json => {errors => [$error]}, status => 404);
}

1;
