package Catmandu::Fix::department_tree;

use Catmandu::Sane;
use Moo;
use App::Helper;
use Dancer qw(:syntax session);

sub fix {
    my ($self, $data) = @_;

    foreach my $d (@{$data->{department}}) {
    	my $dep;
    	$dep = h->search_department({q => [$d->{_id}]})->{hits}->[0];
        $d->{display} = $dep->{display};
    }

    $data;
}

1;
