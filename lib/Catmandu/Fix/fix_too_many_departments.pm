package Catmandu::Fix::fix_too_many_departments;

use Catmandu::Sane;
use Catmandu::Util qw(:array);
use Moo;
use LibreCat::App::Helper;
use Dancer qw(:syntax session);

sub fix {
    my ($self, $data) = @_;

    if ($data->{department}) {
        my $delete_em;
        foreach my $d (@{$data->{department}}) {
            my $full_dep = h->get_department($d->{_id});
            if ($full_dep->{layer} && ($full_dep->{layer} eq "2" || $full_dep->{layer} eq "3")) {
                push @$delete_em, $full_dep->{tree}->[0]->{_id};
            }
            if ($full_dep->{layer} && $full_dep->{layer} eq "3") {
                push @$delete_em, $full_dep->{tree}->[1]->{_id};
            }
        }

        foreach my $del (@$delete_em) {
            my ($index)
                = grep {$data->{department}->[$_]->{_id} eq $del}
                0 .. $#{$data->{department}};
            if (defined $index) {
                splice(@{$data->{department}}, $index, 1);
            }
        }
    }

    $data;
}

1;
