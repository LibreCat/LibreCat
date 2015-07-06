package Catmandu::Fix::add_department;

use Catmandu::Sane;
use Moo;
use App::Helper;
use Dancer qw(:syntax session);

sub fix {
    my ($self, $data) = @_;

    unless ($data->{department}) {
        my $person = h->get_person( session->{personNumber} );
        $data->{department} = $person->{department};
        foreach my $d (@{$data->{$department}}) {
            $d->{tree} = h->get_department($d->{id})->{tree};
        }
    }

    $data;
}

1;
