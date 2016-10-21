package Catmandu::Fix::research_data_doi;

use Catmandu::Sane;
use LibreCat::App::Helper;
use Moo;

sub fix {
    my ($self, $data) = @_;

    if ($data->{type} eq "research_data" && h->config->{doi} && ! $data->{doi}) {
        $data->{doi} = h->config->{doi}->{prefix} . "/" . $data->{_id};
    }

    $data;
}

1;
