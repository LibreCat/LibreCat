package Catmandu::Fix::add_num_of_publs;

use lib qw(/srv/www/pub);

use Catmandu;
use Catmandu::Sane;
use Moo;

Catmandu->load(':up');
my $bag = Catmandu->store('search')->bag('publication');
#my $researchBag = Catmandu->store('search')->bag('researchData');

sub fix {
    my ( $self, $rec ) = @_;

    if($rec->{_id}){
    	my $hits = $bag->search(
		  cql_query => "person=$rec->{_id} AND status=public AND type<>researchData AND type<>dara",
		  limit => 1,
		  start => 0,
		);
		my $resHits = $bag->search(
		  cql_query => "person=$rec->{_id} AND status=public AND (type=researchData OR type=dara)",
		  limit => 1,
		  start => 0,
		);
		$rec->{publication_hits} = $hits->{total};
		$rec->{research_hits} = $resHits->{total};
		$rec->{combined_hits} = int($hits->{total}) + int($resHits->{total});
    }

    $rec;
}

1;
