package Catmandu::Fix::volume_sort;

=head1 NAME

Catmandu::Fix::volume_sort - add a new field "intvolume" (used for sorting by volume)

=head1 SYNOPSIS

   # volume => '5'

   volume_sort()

   # volume => '5',
   # intvolume => '         5'

=cut

use Catmandu::Sane;
use Moo;

# TODO: remove this fix; can sorting by volume be solved directly?

sub fix {
    my ($self, $pub) = @_;

    if ($pub->{volume} and $pub->{volume} =~ /^-?\d{1,}$/) {
        $pub->{intvolume} = sprintf("%10d", $pub->{volume});
    }
    else {
        delete $pub->{intvolume};
    }

    $pub;
}

1;
