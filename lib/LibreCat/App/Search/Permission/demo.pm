package LibreCat::App::Permission::demo;

=head1 NAME

LibreCat::App::Permission::demo - Demonstration permission handler

=head1 SYNOPSIS

  # In permissions.yml
  handlers:
      demo: LibreCat::App::Permission::demo

  routes:
      - [ 'ANY'  , '/demo$', 'demo' ]

  # Now every route to /demo will be checked via the LibreCat::App::Permission::demo
  # package (and redirected to Google)
  
=cut

use Moo;
use Dancer qw(:syntax);

sub route {
    my ($self, $conf) = @_;

    sub {
        return redirect("http://www.google.com");
    };
}

1;
