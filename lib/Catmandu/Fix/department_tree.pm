package Catmandu::Fix::department_tree;

use Catmandu::Sane;
use Moo;
use App::Helper;
use Dancer qw(:syntax session);

sub fix {
    my ($self, $data) = @_;
    
    my $delete_em;

    foreach my $d (@{$data->{department}}) {
    	my $dep;
    	$dep = h->search_department({q => [$d->{_id}]})->{hits}->[0];
    	$d->{tree} = $dep->{tree};
        $d->{display} = $dep->{display};
        
        #my $full_dep = h->get_department($d->{_id});
        if($dep->{layer} eq "2" or $dep->{layer} eq "3"){
            push @$delete_em, $dep->{tree}->[0]->{_id};
        }
        if($dep->{layer} eq "3"){
            push @$delete_em, $dep->{tree}->[1]->{_id};
        }
    }
    
    foreach my $del (@$delete_em){
        my ($index) = grep { $data->{department}->[$_]->{_id} eq $del } 0..$#{$data->{department}};
        if($index){
        	splice(@{$data->{department}}, $index, 1);
        }
    }

    $data;
}

1;
