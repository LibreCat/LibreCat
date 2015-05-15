package Catmandu::Fix::dept_name;

use lib qw(/srv/www/pub);

use Catmandu;
use Catmandu::Sane;
use Moo;

Catmandu->load(':up');
my $mongoBag = Catmandu->store('department')->bag;

sub fix {
    my ( $self, $rec ) = @_;
    
    $rec->{tree} = ();
    
    if($rec->{parent}){
		my $papahit = $mongoBag->get($rec->{parent});
		#$rec->{parent} = {oId => $papahit->{oId}, name => $papahit->{name}};
		#$rec->{parent}->{parent} = $papahit->{parent} if $papahit->{parent};
		if($papahit->{parent}){
			my $mamahit = $mongoBag->get($papahit->{parent});
			#$rec->{parent_of_parent} = {oId => $mamahit->{oId}, name => $mamahit->{name}};
			push @{$rec->{tree}}, $mamahit->{oId} if $mamahit and $mamahit->{oId};
		}
		push @{$rec->{tree}}, $papahit->{oId} if $papahit and $papahit->{oId};
    }
    push @{$rec->{tree}}, $_->{_id};
    
    $rec;
}

1;
