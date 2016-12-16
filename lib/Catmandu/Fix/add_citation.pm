package Catmandu::Fix::add_citation;

use Catmandu::Sane;
use Clone qw(clone);
use LibreCat::App::Helper;
use LibreCat::Citation;
use Moo;

sub fix {
    my ($self, $data) = @_;

    if (h->config->{citation}->{engine} eq 'csl') {
        my $citation_engine = LibreCat::Citation->new(all => 1);

        my $d = clone $data;
        $data->{citation} = $citation_engine->create($d);
    }

    $data;
}

1;
