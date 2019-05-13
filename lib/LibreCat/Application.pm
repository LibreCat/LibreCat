package LibreCat::Application;

use Catmandu::Sane;
use JSON::MaybeXS qw(decode_json);
use Mojo::Base 'Mojolicious';
use namespace::clean;

sub startup {
    my ($self) = @_;

    # add content types
    $self->types->type(yml => 'text/x-yaml');

    $self->plugin('LibreCat::Api');

    my $r = $self->routes;
    $r->namespaces(['LibreCat::Controller']);

    $self->helper(maybe_decode_json => sub {
        my ($self, $json) = @_;
        try {
            decode_json($json);
        } catch {
        };
    });
}

1;

__END__

=pod

=head1 NAME

LibreCat::Application -

=cut
