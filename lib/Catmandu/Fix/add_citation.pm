package Catmandu::Fix::add_citation;

use Catmandu::Sane;
use LibreCat::App::Helper;
use LibreCat::Citation;
use Moo;

sub fix {
    my ($self, $data) = @_;

    unless (h->config->{citation}->{engine} eq 'none') {
        $data->{citation} = LibreCat::Citation->new(all => 1)->create($data);
    }

    return $data;
}

1;
