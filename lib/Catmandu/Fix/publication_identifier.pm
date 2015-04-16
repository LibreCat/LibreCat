package Catmandu::Fix::publication_identifier;

use Catmandu::Sane;
use Moo;
use App::Helper;

sub fix {
    my ($self, $data) = @_;

    if($data->{publication_identifier} and ref $data->{publication_identifier} eq "ARRAY"){
		my $publid_hash;
		foreach my $publid (@{$data->{publication_identifier}}){
			$publid_hash->{$publid->{type}} = [] if !$publid_hash->{$publid->{type}};
			push @{$publid_hash->{$publid->{type}}}, $publid->{value};
		}
		delete $data->{publication_identifier};
		$data->{publication_identifier} = $publid_hash;
	}
	if($data->{external_id} and ref $data->{external_id} eq "ARRAY"){
		my $publid_hash;
		foreach my $publid (@{$data->{external_id}}){
			next if $publid_hash->{$publid->{type}};
			$publid_hash->{$publid->{type}} = $publid->{value};
		}
		delete $data->{external_id};
		$data->{external_id} = $publid_hash;
		foreach my $key (keys %{h->get_list('external_identifier')}){
			if(defined $data->{external_id}->{$key}){
				$data->{$key} = 1;
			}
			else {
				delete $data->{$key} if $data->{$key};
			}
		}
	}
	if($data->{nasc}){
		my @nasc;
		@nasc = split(" ; ", $data->{nasc});
		delete $data->{nasc};
		$data->{nasc} = \@nasc;
	}
	if($data->{genbank}){
		my @genbank;
		@genbank = split(" ; ", $data->{genbank});
		delete $data->{genbank};
		$data->{genbank} = \@genbank;
	}

	return $data;
}

1;
