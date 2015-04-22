package Catmandu::Fix::clean_abstract;

use Catmandu::Sane;
use Moo;

sub fix {
    my ($self, $pub) =@_;

    if($pub->{abstract}){
    	my $i = 0;
    	foreach my $ab (@{$data->{abstract}}){
    		if($ab->{lang} and !$ab->{text}){
    			splice @{$data->{abstract}}, $i, 1;
    		}
    		$i++;
    	}
    }

    return $pub;
}

1;
