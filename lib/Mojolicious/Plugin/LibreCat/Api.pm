package Mojolicious::Plugin::LibreCat::Api;

use Catmandu::Sane;
use LibreCat -self;
use Mojo::Base 'Mojolicious::Plugin';

sub register {
    my ($self, $app, $conf) = @_;

    my $models = librecat->models;
    my $r = $app->routes;

    $r->add_shortcut(
        librecat_api => sub {
            my ($r, $model) = @_;

            my $model_api = $r->any("/$model")->to('api#', model => $model);

            $model_api->get('/:id')->to('#show', model => $model)->name($model);

            $model_api->delete('/:id')->to('#remove', model => $model)->name($model);

            $model_api->post->to('#add', model => $model)->name($model);

            return $model_api;
        }
    );

    my $api = $r->get('/api')->to('api#default');

    $api->librecat_api($_) for @$models;

    # $r->delete('/api/user/:id')->to('api#remove', model => "user")->name("user");
    # $r->delete('/api/publication/:id')->to('api#remove', model => "publication")->name("publication");
    #
    # $r->post('/api/user')->to('api#add', model => "user")->name("user");
    # $r->post('/api/publication')->to('api#add', model => "publication")->name("publication");
}

1;
