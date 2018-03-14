package LibreCat::Backend;

use Catmandu::Sane;
use Mojo::Base 'Mojolicious';
use LibreCat::Model::User;

sub startup {
    my $self = shift;

    push @{$self->plugins->namespaces}, 'LibreCat::Backend::Plugin';

    # Documentation browser under "/perldoc"
    $self->plugin('PODRenderer');

    $self->helper(user => sub {state $user = LibreCat::Model::User->new()});

    # Router
    my $r = $self->routes;

    # Normal route to controller
    $r->get('/api')->to('api#index');
    $r->get('/api/user/:id')->to('api-user#get');
    $r->post('/api/user')->to('api-user#add');
    $r->put('/api/user')->to('api-user#add');
    $r->delete('/api/user/:id')->to('api-user#delete');
}

1;

