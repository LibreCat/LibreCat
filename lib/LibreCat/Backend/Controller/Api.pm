package LibreCat::Backend::Controller::Api;

use Catmandu::Sane;
use Mojo::Base 'Mojolicious::Controller';

sub index {
    my $c = shift;
    $c->render(json => {foo => 'bar'});
}

1;

