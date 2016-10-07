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

    if ($pub->{related_material} and $pub->{related_material}->{link}) {
        my $i = 0;
        foreach my $rm (@{$pub->{related_material}->{link}}) {
            if ($rm->{relation} and !$rm->{url}) {
                splice @{$pub->{related_material}->{link}}, $i, 1;
            }
            $i++;
        }
        if (!$pub->{related_material}->{link}->[0]) {
            delete $pub->{related_material}->{link};
        }
    }

    return $pub;
}

1;
