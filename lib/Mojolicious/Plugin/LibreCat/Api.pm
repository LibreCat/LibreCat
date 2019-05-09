package Mojolicious::Plugin::LibreCat::Api;

use Catmandu::Sane;
use LibreCat -self;
use Mojo::Base 'Mojolicious::Plugin';

sub register {
    my ($self, $app, $conf) = @_;

    my $models = librecat->models;
    my $r      = $app->routes;

    my $api_token = librecat->config->{api_token} // '';

    my $api = $r->any("/api/v1");

    $api->get('/openapi.yml')->to('api_doc#show_openapi_yml');
    $api->get('/openapi.json')->to('api_doc#show_openapi_json');

    my $api_auth = $api->under(
        '/' => sub {
            my $c = shift;

            my $auth_token
                = $c->req->headers->header('Authorization') // '';
            unless ($auth_token) {
                $c->render(
                    json   => {errors => "Not authorized."},
                    status => 401
                );
                return 0;
            }

            if ($auth_token eq $api_token) {

                # authorized
                return 1;
            }
            else {
                # not authorized
                $c->render(
                    json   => {errors => "Not authorized."},
                    status => 401
                );
                return 0;
            }
        }
    );

    $r->add_shortcut(
        librecat_model_api => sub {
            my ($r, $model) = @_;

            my $model_api
                = $api_auth->any("/$model")->to('api#', model => $model);

            ## In Mojolicious HEAD requests are considered equal to GET,
            ## but content will not be sent with the response even if it is present.
            $model_api->get('/:id')->to('#show', model => $model)
                ->name($model);

            $model_api->delete('/:id')->to('#remove', model => $model)
                ->name($model);

            $model_api->put('/:id')->to('#add', model => $model)
                ->name($model);

            $model_api->patch('/:id')->to('#update_fields', model => $model)
                ->name($model);

            $model_api->post->to('#create', model => $model)->name($model);

            if (librecat->$model->does("LibreCat::Model::Plugin::Versioning"))
            {
                $model_api->get('/:id/versions')
                    ->to('#get_history', model => $model)->name($model);
                $model_api->get('/:id/version/:version')
                    ->to('#get_version', model => $model)->name($model);
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
