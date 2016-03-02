package Catmandu::Fix::add_department_tree;

use Catmandu::Sane;
use Moo;
use App::Helper;
use Dancer qw(:syntax session);

sub fix {
    my ($self, $data) = @_;

    foreach my $d (@{$data->{department}}) {
        my $dep;
        if(!$d->{_id} and $d->{id}){
            $d->{_id} = $d->{id};
            delete $d->{id};
        }
        if(!$d->{_id} or $d->{_id} !~ /\d{1,}/){
            #$dep = h->get_department($d->{name});
            $dep = h->search_department({q => ["display=\"$d->{name}\""]})->{hits}->[0];
        }
        else {
            #$dep = h->get_department($d->{_id});
            $dep = h->search_department({q => [$d->{_id}]})->{hits}->[0];
        }
        
        delete $dep->{date_created};
        delete $dep->{_version};
        delete $dep->{date_updated};
        $d = $dep;
        #$d->{tree} = ();
        #$d->{tree} = $dep->{tree} if ($dep and $dep->{tree});
    }

    $data;
}

1;
