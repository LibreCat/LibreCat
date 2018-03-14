package Mojolicious::Plugin::LibreCat::Api;

use Catmandu::Sane;
use Mojo::Base 'Mojolicious::Plugin';

sub register {
    my ($self, $app, $conf) = @_;

    my $r = $app->routes;
    $r->get('/api')->to('api#index');
    $r->get('/api/user/:id')->to('api-user#get');
}

1;
