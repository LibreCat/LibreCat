package Mojolicious::Plugin::LibreCat::Message;

use Catmandu::Sane;
use Catmandu;
use LibreCat -self;
use List::Util qw(any);
use Mojo::Base 'Mojolicious::Plugin';
use namespace::clean;

sub register {
    my ($self, $app, $conf) = @_;

    my $r = $app->routes;
    my $m = $r->any("/message");



}

1;

__END__

=pod

=head1 NAME

Mojolicious::Plugin::LibreCat::Message - message routes

=cut
