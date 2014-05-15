package Catmandu::Fix::clean_suppmat;

use Catmandu::Sane;
use Moo;

sub fix {
	my ( $self, $pub) = @_;
	
	my $related_material;
	
	try{
	
	if($pub->{relatesTo}){
		foreach my $relmat (@{$pub->{relatesTo}}){
			my $hashrec;
			$hashrec->{type} = $relmat->{materialRelationType}->{relationNameTo}->[0]->{text};
			
			if($relmat->{type}->{typeName} eq "relatedMaterialFile"){
				$hashrec->{file}->{file_id} = $relmat->{file}->{fileOId};
				$hashrec->{file}->{file_name} = $relmat->{file}->{fileName};
				$hashrec->{file}->{date_updated} = $relmat->{file}->{dateLastUploaded};
				$hashrec->{file}->{date_created} = $relmat->{file}->{dateCreated} ? $relmat->{hasFile}->{dateCreated} : $relmat->{hasFile}->{dateLastUploaded};
				$hashrec->{file}->{title} = $relmat->{file}->{fileTitle};
				$hashrec->{file}->{description} = $relmat->{file}->{description};
				$hashrec->{file}->{creator} = $relmat->{file}->{uploader}->{login};
				$hashrec->{file}->{access_level} = $relmat->{file}->{accessLevel};
				$hashrec->{file}->{content_type} = $relmat->{file}->{contentType};
				#$hashrec->{file}->{checksum} = ???
				#$hashrec->{file}->{file_size} = ???
			}
			elsif($relmat->{type}->{typeName} eq "relatedMaterialRecord"){
				$hashrec->{record}->{id} = $relmat->{relatesFrom}->{oId};
				#$hashrec->{record}->{title} = $relmat->{relatesFrom}->{mainTitle};
			}
			elsif($relmat->{type}->{typeName} eq "relatedMaterialLink"){
				$hashrec->{"link"}->{url} = $relmat->{"link"}->{url};
				$hashrec->{"link"}->{title} = $relmat->{"link"}->{linkTitle};
				$hashrec->{"link"}->{description} = $relmat->{"link"}->{description};
				$hashrec->{"link"}->{content_type} = $relmat->{"link"}->{contentType};
			}
			
			$hashrec = ();
		}
	}
	
	if($pub->{relatesFrom}){
		foreach my $relmat (@{$pub->{relatesFrom}}){
			my $hashrec;
			$hashrec->{type} = $relmat->{materialRelationType}->{relationNameFrom}->[0]->{text};
			
			if($relmat->{type}->{typeName} eq "relatedMaterialFile"){
				$hashrec->{file}->{file_id} = $relmat->{file}->{fileOId};
				$hashrec->{file}->{file_name} = $relmat->{file}->{fileName};
				$hashrec->{file}->{date_updated} = $relmat->{file}->{dateLastUploaded};
				$hashrec->{file}->{date_created} = $relmat->{file}->{dateCreated} ? $relmat->{hasFile}->{dateCreated} : $relmat->{hasFile}->{dateLastUploaded};
				$hashrec->{file}->{title} = $relmat->{file}->{fileTitle};
				$hashrec->{file}->{description} = $relmat->{file}->{description};
				$hashrec->{file}->{creator} = $relmat->{file}->{uploader}->{login};
				$hashrec->{file}->{access_level} = $relmat->{file}->{accessLevel};
				$hashrec->{file}->{content_type} = $relmat->{file}->{contentType};
				#$hashrec->{file}->{checksum} = ???
				#$hashrec->{file}->{file_size} = ???
			}
			elsif($relmat->{type}->{typeName} eq "relatedMaterialRecord"){
				$hashrec->{record}->{id} = $relmat->{relatesTo}->{oId};
				#$hashrec->{record}->{title} = $relmat->{relatesTo}->{mainTitle};
			}
			elsif($relmat->{type}->{typeName} eq "relatedMaterialLink"){				
				$hashrec->{"link"}->{url} = $relmat->{"link"}->{url};
				$hashrec->{"link"}->{title} = $relmat->{"link"}->{linkTitle};
				$hashrec->{"link"}->{description} = $relmat->{"link"}->{description};
				$hashrec->{"link"}->{content_type} = $relmat->{"link"}->{contentType};
			}
			push @$related_material, $hashrec;
			$hashrec = ();
		}
	}
	
	$pub->{related_material} = $related_material;
	delete $pub->{uploadDirectory} if $pub->{uploadDirectory};
	delete $pub->{relatesTo} if $pub->{relatesTo};
	delete $pub->{relatesFrom} if $pub->{relatesFrom};
	
	$pub;
	}
	catch{
		my $error;
		$error = "An error has occurred.";
		
		$error;
	};

}

1;