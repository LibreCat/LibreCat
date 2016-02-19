package Catmandu::Fix::add_orcid_to_pub;

use Catmandu::Sane;
use Catmandu -load;
use App::Helper;
use Moo;

Catmandu->load(':up');

sub fix {
    my ($self, $data) = @_;

    my $hits = h->search_publication({
    	q => ["person=$data->{_id}"],
    	limit => 1000,
    });

    $hits->each(sub {
    	my $hit = $_[0];
    	if($hit->{author}){
    		foreach my $person (@{$hit->{author}}){
    			if($person->{id} and $person->{id} eq $data->{_id}){
    				$person->{orcid} = $data->{orcid};
    			}
    		}
    	}
    	if($hit->{editor}){
    		foreach my $person (@{$hit->{editor}}){
    			if($person->{id} and $person->{id} eq $data->{_id}){
    				$person->{orcid} = $data->{orcid};
    			}
    		}
    	}
    	my $saved = h->backup_publication_static->add($hit);
    	h->publication->add($saved);
    	h->publication->commit;
    });

}

1;
