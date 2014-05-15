package Catmandu::Fix::move_identifiers;

use Catmandu::Sane;
use Moo;

sub fix {
	my ( $self, $pub ) = @_;
	
	if($pub->{issn} and ref $pub->{issn} eq "ARRAY"){
		foreach my $issn (@{$pub->{issn}}){
			push @{$pub->{publication_identifier}->{issn}}, $issn;
		}
	}
	
	if($pub->{eissn} and ref $pub->{eissn} eq "ARRAY"){
		foreach my $eissn (@{$pub->{eissn}}){
			push @{$pub->{publication_identifier}->{eissn}}, $eissn;
		}
	}
	
	if($pub->{isbn} and ref $pub->{isbn} eq "ARRAY"){
		foreach my $isbn (@{$pub->{isbn}}){
			push @{$pub->{publication_identifier}->{isbn}}, $isbn;
		}
	}
	
	push  @{$pub->{publication_identifier}->{urn}}, $pub->{urn} if $pub->{urn};
	
	
	$pub->{external_id}->{isi} = {id => $pub->{isi}, prefix_id => "ISI:$pub->{isi}"} if $pub->{isi};
	$pub->{external_id}->{arxiv} = {id => $pub->{arxiv}, prefix_id => "arXiv:$pub->{arxiv}"} if $pub->{arxiv};
	$pub->{external_id}->{pmid} = {id => $pub->{medline}, prefix_id => "MEDLINE:$pub->{medline}"} if $pub->{medline};
	$pub->{external_id}->{inspire} = {id=> $pub->{inspire}, prefix_id => "INSPIRE:$pub->{inspire}"} if $pub->{inspire};
	$pub->{external_id}->{ahf} = {id => $pub->{ahf}, prefix_id => "AHF:$pub->{ahf}"} if $pub->{ahf};
	$pub->{external_id}->{scoap3} = {id => $pub->{scoap3}, prefix_id => "SCOAP3:$pub->{scoap3}"} if $pub->{scoap3};
	$pub->{external_id}->{phillister} = {id => $pub->{phillister}, prefix_id => "PhilLister:$pub->{phillister}"} if $pub->{phillister};
	$pub->{external_id}->{opac} = {id => $pub->{opac}, prefix_id => "UB-OPAC:$pub->{opac}"} if $pub->{opac};
	$pub->{external_id}->{fp7} = {id => $pub->{fp7}, prefix_id => $pub->{fp7}} if $pub->{fp7};
	$pub->{external_id}->{fp6} = {id => $pub->{fp6}, prefix_id => $pub->{fp6}} if $pub->{fp6};
	
	$pub->{external_id}->{nasc} = $pub->{nascseedstockID} if $pub->{nascseedstockID};
	$pub->{external_id}->{genbank} = $pub->{genbankID} if $pub->{genbankID};	
	
	$pub;
}

1;