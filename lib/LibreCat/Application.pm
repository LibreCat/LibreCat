package LibreCat::Application;

use Catmandu::Sane;
use JSON::MaybeXS qw(decode_json);
use LibreCat -self;
use Mojo::Base 'Mojolicious';
use namespace::clean;

sub startup {
    my ($self) = @_;

    # add content types
    $self->types->type(yml => 'text/x-yaml');

    # controller namespace
    my $r = $self->routes;
    $r->namespaces(['LibreCat::Controller']);

    # hardcoded for now
    $self->plugin('LibreCat::Api');

    $self->plugin('TemplateToolkit');

    push @{$self->renderer->paths}, @{librecat->template_paths};

    $r->any(
        '/*whatever' => {whatever => ''} => sub {
            my $c        = shift;
            my $whatever = $c->param('whatever');
            $c->render(template => '404', handler => 'tt2', status => 404);
        }
    );

    # helpers
    $self->helper(
        maybe_decode_json => sub {
            my ($self, $json) = @_;
            try {
                decode_json($json);
            }
            catch {
            };
        }
    );
}

1;

__END__

=pod

=head1 NAME

LibreCat::Application -

=cut
