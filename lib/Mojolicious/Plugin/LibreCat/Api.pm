package Mojolicious::Plugin::LibreCat::Api;

use Catmandu::Sane;
use Catmandu;
use LibreCat -self;
use List::Util qw(any);
use Mojo::Base 'Mojolicious::Plugin';
use namespace::clean;

sub register {
    my ($self, $app, $conf) = @_;

    my $models       = librecat->models;
    my $token_secret = librecat->config->{api}{v1}{token_secret};
    my $r            = $app->routes;

    #Note: path /api only known by bin/app.pl
    my $api = $r->any("/v1");

    $api->get('/openapi.yml')->to('api#openapi_yml');
    $api->get('/openapi.json')->to('api#openapi_json');

    my $api_auth = $api->under(
        '/' => sub {
            my $c     = shift;
            my $token = $c->req->headers->header('Authorization');

            # authorized
            if (librecat->token->decode($token)) {
                return 1;
            }

            # not authorized
            $c->render(json => {errors => ["Not authorized"]}, status => 401);
            0;
        }
    );

    $r->add_shortcut(
        librecat_model_api => sub {
            my ($r, $model) = @_;

            my $model_api = $api_auth->any("/$model")
                ->to('model_api#', model => $model);

            $model_api->get('/search')->to('#search', model => $model)
                ->name($model);

            ## In Mojolicious HEAD requests are considered equal to GET,
            ## but content will not be sent with the response even if it is present.
            # GET /api/v1/:model/:id
            $model_api->get('/:id')->to('#show', model => $model)
                ->name($model);

            # DELETE /api/v1/:model/:id
            $model_api->delete('/:id')->to('#remove', model => $model)
                ->name($model);

            # PUT /api/v1/:model/:id
            $model_api->put('/:id')->to('#update', model => $model)
                ->name($model);

            # PUT /api/v1/:model/:id
            $model_api->patch('/:id')->to('#update_fields', model => $model)
                ->name($model);

            # POST /api/v1/:model
            $model_api->post->to('#create', model => $model)->name($model);

            if (librecat->$model->does("LibreCat::Model::Plugin::Versioning"))
            {
                $model_api->get('/:id/versions')
                    ->to('#show_history', model => $model)->name($model);
                $model_api->get('/:id/version/:version')
                    ->to('#show_version', model => $model)->name($model);
            }

            return $model_api;
        }
    );

    $r->librecat_model_api($_) for @$models;
}

1;

__END__

=pod

=head1 NAME

Mojolicious::Plugin::LibreCat::Api - the api route dispatcher

=cut
