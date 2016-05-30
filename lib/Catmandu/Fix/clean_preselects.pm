package Catmandu::Fix::clean_preselects;

use Catmandu::Sane;
use Moo;

sub fix {
    my ($self, $pub) = @_;

    if ($pub->{abstract}) {
        my $i = 0;
        foreach my $ab (@{$pub->{abstract}}) {
            if ($ab->{lang} and !$ab->{text}) {
                splice @{$pub->{abstract}}, $i, 1;
            }
            $i++;
        }
    }

    return $pub;
}

1;
