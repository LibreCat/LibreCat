package Catmandu::Fix::volume_sort;

use Catmandu::Sane;
use Moo;

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
