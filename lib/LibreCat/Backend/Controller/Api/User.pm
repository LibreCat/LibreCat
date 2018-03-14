package LibreCat::Backend::Controller::Api::User;

use Catmandu::Sane;
use Mojo::Base 'Mojolicious::Controller';

sub get {
    my $c    = shift;
    my $user = $c->user;
    $c->render(json => {data => $user->get($c->param('id'))});
}

1;
