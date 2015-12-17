package Catmandu::Fix::add_department;

use Catmandu::Sane;
use Moo;
use App::Helper;
use Dancer qw(:syntax session);

sub fix {
    my ($self, $data) = @_;

	eval {
	    unless ($data->{department} and session->{personNumber}) {
	        my $person = h->get_person( session->{personNumber} );
	        $data->{department} = $person->{department};
	        foreach my $d (@{$data->{department}}) {
	            $d->{tree} = h->get_department($d->{_id})->{tree};
	        }
	    }
	};

	if ($@) {
		# no nothing when we don't have a session
	}

    $data;
}

1;
