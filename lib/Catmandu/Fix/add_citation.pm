package Catmandu::Fix::add_citation;

use Catmandu::Sane;
use Moo;
use Citation;

# TODO: make path configurable

sub fix {
    my ($self, $data) = @_;

    $data->{citation} = Citation->new(all => 1)->create($data);

    return $data;
}

1;
