package Catmandu::Fix::clean_link;

use Catmandu::Sane;
use Moo;

sub fix {
	my ( $self, $pub ) = @_;
	my $link;
	
	if($pub->{"link"} and ref $pub->{"link"} eq "ARRAY"){
		foreach my $li (@{$pub->{"link"}}){
			push @$link, $li->{url} if $li->{url};
		}
		delete $pub->{"link"};
		$pub->{"link"} = $link;
	}
	
	$pub;
}

1;