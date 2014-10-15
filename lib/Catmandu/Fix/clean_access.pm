package Catmandu::Fix::clean_access;

use lib qw(/srv/www/app-catalog);

use Catmandu;
use Catmandu::Sane;
use Moo;

Catmandu->load('/srv/www/app-catalog');

sub fix {
    my ( $self, $rec ) = @_;
    
    if($rec->{access}){
    	foreach my $acc (@{$rec->{access}}){
    		$acc->{id} = $acc->{organizationNumber};
    		delete $acc->{organizationNumber};
    	}
    }

    
    $rec;
}

1;
