package Catmandu::Fix::add_department_tree;

use Catmandu::Sane;
use Moo;
use App::Helper;
use Dancer qw(:syntax session);

sub fix {
    my ($self, $data) = @_;

    foreach my $d (@{$data->{department}}) {
    	my $dep;
    	if($d->{_id} !~ /\d{1,}/){
    		$dep = h->get_department($d->{name});
    	}
    	else {
    		$dep = h->get_department($d->{_id});
    	}
        
        $d->{tree} = ();
        $d->{tree} = $dep->{tree} if ($dep and $dep->{tree});
    }

    $data;
}

1;
