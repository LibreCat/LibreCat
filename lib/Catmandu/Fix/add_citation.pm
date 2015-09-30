package Catmandu::Fix::add_citation;

use Catmandu::Sane;
use Catmandu qw(export_to_string);
use Citation;
use Moo;


# TODO: make path configurable

my $conf = Catmandu->config->{citation};

sub fix {
    my ($self, $data) = @_;

    $data->{citation} = Citation->new(all => 1)->create($data);

    return $data;
}

1;
