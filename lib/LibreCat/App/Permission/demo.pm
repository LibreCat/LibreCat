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
  # package if the access is from a local system, then allow access, otherwise
  # deny all access.

=cut

use Moo;
use LibreCat::App::Helper;
use Dancer qw(:syntax);

sub route {
    my ($self, $conf) = @_;

    sub {
        my $ip_range = [qw(127.0.0.1 10.0.2.1)];
        my $ip = request->address;
        if (h->within_ip_range($ip, $ip_range)) {
            h->log->debug("allow access for $ip");
        }
        else {
            h->log->error("deny access for $ip");
            return redirect uri_for('/access_denied');
        }
    };
}

1;
