package Catmandu::Fix::publication_to_templ_exp;

use Catmandu::Sane;
use Catmandu;
use Moo;
use Dancer qw(:syntax request);

Catmandu->load('/srv/www/sbcat/PUBSearch');
my $conf = Catmandu->config;
my $ip = request->address();

sub fix {
  my ($self, $pub) = @_;
  
  $pub->{host} = $conf->{env}->{$ip}->{host};
  $pub->{app} = $conf->{app};

  foreach ( keys %{$conf->{export}->{mime_types}} ) {
    push @{$pub->{formats}}, $conf->{export}->{mime_types}->{$_};
  }

  #map { @{$pub->{formats}}, keys$conf->{export}->{mime_types}->{$_}; } keys %$conf->{export}->{mime_types};

  $pub;
}

1;