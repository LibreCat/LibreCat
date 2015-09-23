package Catmandu::Fix::add_citation;

use Catmandu::Sane;
use Catmandu qw(export_to_string);
use Citation;
use Moo;

Catmandu->load(':up');

# TODO: make path configurable

my $conf = Catmandu->config->{citation};

sub fix {
    my ($self, $data) = @_;

    if ($conf->{engine} eq 'template') {
        $data->{citation}->{default} = export_to_string($data, 'Template', $conf->{template});
    } elsif ($conf->{engine} eq 'csl') {
        $data->{citation} = Citation->new(all => 1)->create($data);
    }

    return $data;
}

1;
