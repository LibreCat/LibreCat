package Catmandu::Fix::clean_preselects;

=pod

=head1 NAME

Catmandu::Fix::clean_preselects - cleans empty abstract and related_material.link

=cut

use Catmandu::Sane;
use Moo;

sub fix {
    my ($self, $pub) = @_;

    if ($pub->{abstract}) {
        my @new_abstract;

        for my $ab (@{$pub->{abstract}}) {
            push @new_abstract, $ab if ($ab->{lang} && $ab->{text});
        }

        if (@new_abstract) {
            $pub->{abstract} = \@new_abstract;
        }
        else {
            delete $pub->{abstract};
        }
    }

    if ($pub->{related_material} and $pub->{related_material}->{link}) {
        my @new_link;

        for my $rm (@{$pub->{related_material}->{link}}) {
            push @new_link, $rm if  ($rm->{relation} && $rm->{url});
        }

        if (@new_link) {
            $pub->{related_material}->{link} = \@new_link;
        }
        else {
            delete $pub->{related_material}->{link};
        }
    }

    return $pub;
}

1;
