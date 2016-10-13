package Catmandu::Fix::add_citation;

use Catmandu::Sane;
use Catmandu::Fix::clone as => 'clone';
use LibreCat::App::Helper;
use LibreCat::Citation;
use Moo;

sub fix {
    my ($self, $data) = @_;

    unless (h->config->{citation}->{engine} eq 'none') {
        my $d = clone $data;
        $data->{citation} = LibreCat::Citation->new(all => 1)->create($d);
    }

    return $data;
}

1;
