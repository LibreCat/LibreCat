package Catmandu::Fix::add_citation;

use Catmandu::Sane;
use Catmandu qw(export_to_string);
use Catmandu::Fix::clone as => 'clone';
use LibreCat::Citation;
use Moo;

sub fix {
    my ($self, $data) = @_;

    my $d = clone $data;
    $data->{citation} = LibreCat::Citation->new(all => 1)->create($d);

    return $data;
}

1;
