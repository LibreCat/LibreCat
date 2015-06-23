package Catmandu::Fix::clean_aff;

use Catmandu::Sane;
use Catmandu;

Catmandu->load(':up');
Catmandu->config;

my $bag;
sub fix {
  my ($self, $pub) = @_;

  my @trees;
  map {
    push @trees, {id => $_->{id}, tree => $bag->get($_->{id})->{tree}};
  } @{$pub->{department}};
  my @ntree = sort {$a <=> $b} length @tree...;

  foreach (...) {
    array includes
  }
}

1;
