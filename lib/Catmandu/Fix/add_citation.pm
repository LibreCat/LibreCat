package Catmandu::Fix::add_citation;

use Catmandu::Sane;
use Moo;
use Citation;

sub fix {
    my ($self, $data) = @_;

    $data->{citation} = Citation->new(styles => [...])->create($data);

    return $data;
}

1;
