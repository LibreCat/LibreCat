package Catmandu::Fix::add_department_tree;

use Catmandu::Sane;
use Moo;
use LibreCat::App::Helper;
use LibreCat;
use Dancer qw(:syntax session);

sub fix {
    my ($self, $data) = @_;

    foreach my $d (@{$data->{department}}) {
        my $dep;
        if (!$d->{_id} and $d->{id}) {
            $d->{_id} = $d->{id};
            delete $d->{id};
        }
        if (!$d->{_id} or $d->{_id} !~ /\d{1,}/) {
            $dep = LibreCat->searcher->search('department', {q => ["display=\"$d->{name}\""]})
                ->{hits}->[0];
        }
        else {
            $dep = LibreCat->searcher->search('department', {q => [$d->{_id}]})->{hits}->[0];
        }

        delete $dep->{date_created};
        delete $dep->{_version};
        delete $dep->{date_updated};
        $d = $dep;
    }

    $data;
}

1;
