package Catmandu::Fix::clean_reviewer;

use lib qw(/srv/www/app-catalog);

use Catmandu;
use Catmandu::Sane;
use Moo;

Catmandu->load('/srv/www/app-catalog');

sub fix {
    my ( $self, $rec ) = @_;
    
    if($rec->{reviewer}){
    	foreach my $rev (@{$rec->{reviewer}}){
    		delete $rev->{reviewer} if $rev->{reviewer};
    		delete $rev->{reviewDiss} if $rev->{reviewDiss};
    		$rev->{id} = $rev->{department}->{id};
    		$rev->{name} = $rev->{department}->{name};
    		delete $rev->{department};
    	}
    }

    
    $rec;
}

1;
