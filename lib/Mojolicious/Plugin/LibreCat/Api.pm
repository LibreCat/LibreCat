package Mojolicious::Plugin::LibreCat::Api;

use Catmandu::Sane;
use LibreCat;
use Mojo::Base 'Mojolicious::Plugin';

sub register {
    my ($self, $app, $conf) = @_;

    my $r = $app->routes;

    $r->add_shortcut(librecat_api => sub {
       my ($r, $model) = @_;

       my $model_api = $r->any("/$model")->to('api#', model => $model);

       $model_api->get('/:id')->to('#show', model => $model)->name($model);

       $model_api;
   });

    my $api = $r->get('/api')->to('api#default');

    $api->librecat_api($_) for @{LibreCat->models};
}

1;
