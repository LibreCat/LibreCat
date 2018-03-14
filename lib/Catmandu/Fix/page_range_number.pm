package Catmandu::Fix::page_range_number;

=pod

=head1 NAME

Catmandu::Fix::page_range_number - translates the form page_range_number into article_number and page

=cut

use Catmandu::Sane;
use LibreCat::App::Helper;
use Moo;

sub fix {
    my ($self, $data) = @_;

    if ($data->{page_range_number}) {
        if (    $data->{page_range_number}->{type}
            and $data->{page_range_number}->{type} eq "article_number")
        {
            $data->{article_number} = $data->{page_range_number}->{value};
        }
        else {
            $data->{page} = $data->{page_range_number}->{value};
        }
        delete $data->{page_range_number};
    }

    return $data;
}

1;
