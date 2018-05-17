package Template::Plugin::LibreCat::App::Helper;
use base qw( Template::Plugin );
use Template::Plugin;
use LibreCat::App::Helper;

sub new {
    my $class   = shift;
    my $context = shift;
    $context->stash->set('h',h);
    bless {}, $class;
}

=head1 NAME

Template::Plugin::LibreCat::Helper - injects the helper functions.

=head1 SYNOPSIS

    # in your templates
    [% USE LibreCat::App::Helper %]
    [% h.get_department(id) %]

=cut


1;
