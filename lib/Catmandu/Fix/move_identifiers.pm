package Catmandu::Fix::move_identifiers;

use Catmandu::Sane;
use Moo;

sub fix {
	my ( $self, $pub ) = @_;
	
	if($pub->{issn} and ref $pub->{issn} eq "ARRAY"){
		foreach my $issn (@{$pub->{issn}}){
			push @{$pub->{publication_identifier}->{issn}}, $issn;
		}
		delete $pub->{issn};
	}
	
	if($pub->{eissn} and ref $pub->{eissn} eq "ARRAY"){
		foreach my $eissn (@{$pub->{eissn}}){
			push @{$pub->{publication_identifier}->{eissn}}, $eissn;
		}
		delete $pub->{eissn};
	}
	
	if($pub->{isbn} and ref $pub->{isbn} eq "ARRAY"){
		foreach my $isbn (@{$pub->{isbn}}){
			push @{$pub->{publication_identifier}->{isbn}}, $isbn;
		}
		delete $pub->{isbn};
	}
	
	if($pub->{eisbn} and ref $pub->{eisbn} eq "ARRAY"){
		foreach my $eisbn (@{$pub->{eisbn}}){
			push @{$pub->{publication_identifier}->{eisbn}}, $eisbn;
		}
		delete $pub->{isbn};
	}
	
	push  @{$pub->{publication_identifier}->{urn}}, $pub->{urn} if $pub->{urn};
	delete $pub->{urn} if $pub->{urn};
	
	
	$pub->{external_id}->{isi} = $pub->{isi} if $pub->{isi};
	delete $pub->{isi} if $pub->{isi};
	$pub->{external_id}->{arxiv} = $pub->{arxiv} if $pub->{arxiv};
	delete $pub->{arxiv} if $pub->{arxiv};
	$pub->{external_id}->{pmid} = $pub->{medline} if $pub->{medline};
	delete $pub->{medline} if $pub->{medline};
	$pub->{external_id}->{inspire} = $pub->{inspire} if $pub->{inspire};
	delete $pub->{inspire} if $pub->{inspire};
	$pub->{external_id}->{ahf} = $pub->{ahf} if $pub->{ahf};
	delete $pub->{ahf} if $pub->{ahf};
	$pub->{external_id}->{scoap3} = $pub->{scoap3} if $pub->{scoap3};
	delete $pub->{scoap3} if $pub->{scoap3};
	$pub->{external_id}->{phillister} = $pub->{phillister} if $pub->{phillister};
	delete $pub->{phillister} if $pub->{phillister};
	$pub->{external_id}->{opac} = $pub->{opac} if $pub->{opac};
	delete $pub->{opac} if $pub->{opac};
	$pub->{external_id}->{fp7} = $pub->{fp7} if $pub->{fp7};
	delete $pub->{fp7} if $pub->{fp7};
	$pub->{external_id}->{fp6} = $pub->{fp6} if $pub->{fp6};
	delete $pub->{fp6} if $pub->{fp6};
	
	$pub->{external_id}->{nasc} = $pub->{nascseedstockID} if $pub->{nascseedstockID};
	delete $pub->{nascseedstockID} if $pub->{nascseedstockID};
	$pub->{external_id}->{genbank} = $pub->{genbankID} if $pub->{genbankID};
	delete $pub->{genbankID} if $pub->{genbankID};
	
	$pub;
}

1;