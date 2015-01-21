package Catmandu::Fix::clean_suppmat;

use Catmandu::Sane;
use Moo;

sub fix {
	my ( $self, $pub) = @_;
	
	my $rel_map =  {
    	"Related object is erratum" => "erratum",
    	"Related object is table of contents" => "table_of_contents",
    	"Related object is confirmation" => "confirmation",
    	"Related object is supplementary material" => "supplementary_material",
    	"Other relation" => "other",
    	"This object is cited by" => "is_cited_by",
    	"This document cites related object" => "cites",
    	"Related object is earlier version" => "earlier_version",
    	"Related object is later version" => "later_version",
    	"Related object is part of" => "contains",
    	"This document is part of related object" => "published_in",
    	"This document is a part of Dissertation" => "part_of_dissertation",
    	"Related object is article/paper in dissertation" => "dissertation_contains",
    	"Related object is old edition" => "old_edition",
    	"Related object is new edition" => "new_edition",
    	"Related object continues" => "continues",
    	"Related object is continued by" => "is_continued_by",
    	"Related object is popular science" => "popular_science",
    	"This object is popular science of related object" => "research_paper",
    };
	my $related_material;
	
	if($pub->{relatesTo}){
		foreach my $relmat (@{$pub->{relatesTo}}){
			my $hashrec;
			$hashrec->{relation} = $rel_map->{$relmat->{materialRelationType}->{relationNameTo}->[0]->{text}} if $relmat->{materialRelationType}->{relationNameTo}->[0]->{text};
			
			if($relmat->{type}->{typeName} eq "relatedMaterialFile"){
				$hashrec->{file_id} = $relmat->{file}->{fileOId};
				$hashrec->{file_name} = $relmat->{file}->{fileName};
				$hashrec->{date_updated} = $relmat->{file}->{dateLastUploaded};
				$hashrec->{date_created} = $relmat->{file}->{dateCreated} ? $relmat->{hasFile}->{dateCreated} : $relmat->{hasFile}->{dateLastUploaded};
				$hashrec->{title} = $relmat->{file}->{fileTitle};
				$hashrec->{description} = $relmat->{file}->{description};
				$hashrec->{creator} = $relmat->{file}->{uploader}->{login};
				$hashrec->{access_level} = $relmat->{file}->{accessLevel};
				$hashrec->{open_access} = $hashrec->{access_level} eq "open_access" ? 1 : 0;
				#$hashrec->{request_a_copy} = doesn't exist yet
				#$hashrec->{embargo} = ???
				$hashrec->{year_last_uploaded} = substr($relmat->{file}->{dateLastUploaded},0,4);
				$hashrec->{content_type} = $relmat->{file}->{contentType};
				#$hashrec->{checksum} = ???
				#$hashrec->{file_size} = ???
				push @{$pub->{file}}, $hashrec;
			}
			elsif($relmat->{type}->{typeName} eq "relatedMaterialRecord"){
				$hashrec->{id} = $relmat->{relatesFrom}->{oId};
				push @{$related_material->{record}}, $hashrec;
			}
			elsif($relmat->{type}->{typeName} eq "relatedMaterialLink"){
				$hashrec->{url} = $relmat->{"link"}->{url};
				$hashrec->{title} = $relmat->{"link"}->{linkTitle};
				$hashrec->{description} = $relmat->{"link"}->{description};
				push @{$related_material->{link}}, $hashrec;
			}
			$hashrec = ();
		}
	}
	
	if($pub->{relatesFrom}){
		foreach my $relmat (@{$pub->{relatesFrom}}){
			my $hashrec;
			$hashrec->{relation} = $rel_map->{$relmat->{materialRelationType}->{relationNameFrom}->[0]->{text}};
			
			if($relmat->{type}->{typeName} eq "relatedMaterialFile"){
				$hashrec->{file_id} = $relmat->{file}->{fileOId};
				$hashrec->{file_name} = $relmat->{file}->{fileName};
				$hashrec->{date_updated} = $relmat->{file}->{dateLastUploaded};
				$hashrec->{date_created} = $relmat->{file}->{dateCreated} ? $relmat->{hasFile}->{dateCreated} : $relmat->{hasFile}->{dateLastUploaded};
				$hashrec->{title} = $relmat->{file}->{fileTitle};
				$hashrec->{description} = $relmat->{file}->{description};
				$hashrec->{creator} = $relmat->{file}->{uploader}->{login};
				$hashrec->{access_level} = $relmat->{file}->{accessLevel};
				$hashrec->{open_access} = ($hashrec->{access_level} and $hashrec->{access_level} eq "open_access") ? 1 : 0;
				#$hashrec->{request_a_copy} = doesn't exist yet
				#$hashrec->{embargo} = ???
				$hashrec->{year_last_uploaded} = substr($hashrec->{date_updated},0,4) if $hashrec->{date_updated};
				$hashrec->{content_type} = $relmat->{file}->{contentType};
				#$hashrec->{checksum} = ???
				#$hashrec->{file_size} = ???
				push @{$pub->{file}}, $hashrec;
			}
			elsif($relmat->{type}->{typeName} eq "relatedMaterialRecord"){
				$hashrec->{id} = $relmat->{relatesTo}->{oId};
				push @{$related_material->{record}}, $hashrec;
			}
			elsif($relmat->{type}->{typeName} eq "relatedMaterialLink"){				
				$hashrec->{url} = $relmat->{"link"}->{url};
				$hashrec->{title} = $relmat->{"link"}->{linkTitle};
				$hashrec->{description} = $relmat->{"link"}->{description};
				push @{$related_material->{link}}, $hashrec;
			}
			$hashrec = ();
		}
	}
	
	$pub->{related_material} = $related_material if $related_material;
	delete $pub->{uploadDirectory} if $pub->{uploadDirectory};
	delete $pub->{relatesTo} if $pub->{relatesTo};
	delete $pub->{relatesFrom} if $pub->{relatesFrom};
	
	$pub;

}

1;