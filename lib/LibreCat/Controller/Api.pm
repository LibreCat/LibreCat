package LibreCat::Controller::Api;

use Catmandu::Sane;
use LibreCat -self;
use Mojo::Base 'Mojolicious::Controller';

sub default {
    my $c = shift;
    $c->render(json => {foo => 'bar'});
}

sub show {
    my $c     = $_[0];
    my $model = $c->param('model');
    my $id    = $c->param('id');
    my $recs  = librecat->$model;
    my $rec   = $recs->get($id) || return $c->not_found;
    delete $rec->{_id};
    my $data = {
        type       => $model,
        id         => $id,
        attributes => $rec,
        links      => {self => $c->url_for->to_abs,},
    };
    $c->render(json => {data => $data});
}

sub not_found {
    my $c     = $_[0];
    my $model = $c->param('model');
    my $id    = $c->param('id');
    my $error = {
        status => '404',
        title  => "$model $id not found",
        source => {parameter => 'id'},
    };
    $c->render(json => {errors => [$error]}, status => 404);
}

1;
