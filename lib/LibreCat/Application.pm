package LibreCat::Application;

use Catmandu::Sane;
use Mojo::Base 'Mojolicious';

sub startup {
    my ($self) = @_;

    $self->plugin('LibreCat::Api');

    my $r = $self->routes;
    $r->namespaces(['LibreCat::Controller']);
}

1;

