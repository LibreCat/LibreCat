package Catmandu::Fix::add_doi;

=head1 NAME

Catmandu::Fix::add_doi - create a doi from the _id field

=head1 CONFIGURATION

Requires doi.prefix set in the configuration files

=cut

use Catmandu::Sane;
use LibreCat::App::Helper;
use Moo;

sub fix {
    my ($self, $data) = @_;

    if (exists h->config->{doi} && $data->{_id}) {
        $data->{doi} = h->config->{doi}->{prefix} . "/" . $data->{_id};
    }

    $data;
}

1;
