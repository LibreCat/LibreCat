package Catmandu::Fix::move_identifiers;

use Catmandu::Sane;
use Moo;

sub fix {
	my ( $self, $pub ) = @_;
	
	if($pub->{issn} and ref $pub->{issn} eq "ARRAY"){
		foreach my $issn (@{$pub->{issn}}){
			push @{$pub->{publication_identifier}}, {issn => $issn};
		}
	}
	
	if($pub->{eissn} and ref $pub->{eissn} eq "ARRAY"){
		foreach my $eissn (@{$pub->{eissn}}){
			push @{$pub->{publication_identifier}}, {eissn => $eissn};
		}
	}
	
	if($pub->{isbn} and ref $pub->{isbn} eq "ARRAY"){
		foreach my $isbn (@{$pub->{isbn}}){
			push @{$pub->{publication_identifier}}, {isbn => $isbn};
		}
	}
	
	push  @{$pub->{publication_identifier}}, {urn => $pub->{urn}} if $pub->{urn};
	
	
	push @{$pub->{external_id}}, {isi => $pub->{isi}} if $pub->{isi};
	push @{$pub->{external_id}}, {arxiv => $pub->{arxiv}} if $pub->{arxiv};
	push @{$pub->{external_id}}, {pubmed => $pub->{medline}} if $pub->{medline};
	push @{$pub->{external_id}}, {inspire => $pub->{inspire}} if $pub->{inspire};
	push @{$pub->{external_id}}, {ahf => $pub->{ahf}} if $pub->{ahf};
	push @{$pub->{external_id}}, {scoap3 => $pub->{scoap3}} if $pub->{scoap3};
	push @{$pub->{external_id}}, {phillister => $pub->{phillister}} if $pub->{phillister};
	push @{$pub->{external_id}}, {opac => $pub->{opac}} if $pub->{opac};
	push @{$pub->{external_id}}, {fp7 => $pub->{fp7}} if $pub->{fp7};
	push @{$pub->{external_id}}, {fp6 => $pub->{fp6}} if $pub->{fp6};
	
	
	#genbank: []
	#nasc: []
	
	
	$pub;
}

1;