package Catmandu::Fix::person;

use Catmandu::Sane;
use Moo;

sub fix{
    my ($self, $data) = @_;
    my @p = qw(author editor translator supervisor);

    foreach my $pers (@p) {
        next unless $data->{$pers};
        map {
            if ($_->{first_name} and $_->{last_name}) {
                $_->{full_name} = $_->{last_name} . ", " .$_->{first_name};
            }
        } @{$data->{$pers}};
    }
    return $data;
}

1;
