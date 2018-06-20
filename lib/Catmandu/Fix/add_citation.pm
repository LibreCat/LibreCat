package Catmandu::Fix::add_citation;

=pod

=head1 NAME

Catmandu::Fix::add_citation - add a 'citation' field calculated from the data

=cut

use Catmandu::Sane;
use LibreCat::Citation;
use Moo;

has citation_engine => (is => 'lazy');

sub _build_citation_engine {
    LibreCat::Citation->new(all => 1);
}

sub fix {
    my ($self, $data) = @_;

    my $citation_engine = $self->citation_engine;
    my $citation        = $citation_engine->create($data);

    if ($citation) {
        $data->{citation} = $citation;
    }

    $data;
}

1;
