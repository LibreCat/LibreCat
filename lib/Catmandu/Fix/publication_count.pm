package Catmandu::Fix::publication_count;

=pod

=head1 NAME

Catmandu::Fix::publication_count - add a 'publication_count' field calculated from the user data

=cut

use Catmandu::Sane;
use Catmandu::Util qw(:is);
use LibreCat qw(:self);
use Moo;

sub fix {
    my ($self, $data) = @_;

    $data->{publication_count} = librecat->model("publication")->search(
        cql_query => "person=".$data->{_id}." AND status=public",
        limit => 0
    )->total();

    $data;
}

1;
