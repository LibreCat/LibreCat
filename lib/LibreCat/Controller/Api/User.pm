package LibreCat::Controller::Api::User;

use Catmandu::Sane;
use Mojo::Base 'Mojolicious::Controller';
use LibreCat;

sub get {
    my $c    = shift;
    $c->render(json => {data => LibreCat->user->get($c->param('id'))});
}

1;
