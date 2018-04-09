package Catmandu::Fix::librecat_uri_base;

=head1 NAME

Catmandu::Fix::librecat_uri_base - set path to uri_base of librecat

=head1 SYNOPSIS

librecat_uri_base('uri_base')

=cut

use Catmandu::Sane;
use Moo;
use LibreCat::App::Helper;
use Catmandu::Fix::Has;

with 'Catmandu::Fix::Base';

has path => (fix_arg => 1);

sub emit {
    my ($self, $fixer) = @_;

    my $path     = $fixer->split_path($self->path);
    my $uri_base = LibreCat::App::Helper::Helpers->new()->uri_base();

    $fixer->emit_create_path(
        $fixer->var,
        $path,
        sub {
            my $var = shift;
            qq(${var} = "${uri_base}";);
        }
    );
}

1;
