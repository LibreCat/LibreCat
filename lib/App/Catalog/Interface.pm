package App::Catalog::Interface;

use Catmandu::Sane;
use Catmandu::Util qw(:array);
use Dancer ':syntax';
use Dancer::Request;
use App::Catalog::Helper;

get '/search_researcher' => sub {
	my $q = params->{'ftext'};
	my $hits = h->search_researcher({q => $q});
	
	#use to_json

	my $jsonstring = "[";
	foreach (@{$hits->{hits}}){
		my $pevzId = $_->{_id};
		my $sbcatId = $_->{sbcatId};
		my $firstName = $_->{givenName};
		$firstName =~ s/"/\\"/g;
		my $lastName = $_->{surname};
		$lastName =~ s/"/\\"/g;
		my $title = $_->{bis_personTitle} || "";
		$jsonstring .= "{pevzId:\"" . $pevzId . "\"";
		$jsonstring .= ", sbcatId:\"" . $sbcatId . "\"";
		$jsonstring .= ", firstName:\"" . $firstName . "\"";
		$jsonstring .= ", lastName:\"" . $lastName . "\"";
		$jsonstring .= ", title:\"" . $title ."\"";
		$jsonstring .= "},";
	}
	$jsonstring =~ s/,$//g;
	$jsonstring .= "]";
	return $jsonstring;
};

get '/autocomplete_hierarchy' => sub {
	my $q = params->{'term'} || "";
	my $fmt = params->{fmt} || "autocomplete";
	my $type = params->{type} || "department";
	$q = "name=" . $q . "*" if ($q ne "" and $type ne "researchgroup");
	my $hits;
	
	if($type eq "department"){
		$hits = h->search_department({q => $q, limit => 1000, sort => "name,,0"});
	}
	elsif($type eq "project"){
		$hits = h->search_project({q => $q, limit => 1000});
	}
	elsif($type eq "researchgroup"){
		$hits = h->search_researchgroup({q => $q});
	}
	my $jsonhash = ();
	my $sorted;
	my $fullsort;
	
	#to_dumper($hits);
	
	if($fmt eq "autocomplete"){
		foreach (@{$hits->{hits}}){
			my $label = "";
			$label = $_->{name};
			
			if($_->{parent}){
				$label .= " (";
				if($_->{parent_of_parent}){
					$label .= $_->{parent_of_parent}->{name} . " | ";
				}
				$label .=  $_->{parent}->{name} . ")";
			}
			
			$label =~ s/"/\\"/g;
			push @$jsonhash, {id => $_->{oId}, label => $label};
		}
	}
	else{
		foreach (@{$hits->{hits}}){
			push @$jsonhash, {id => $_->{_id}, label => $_->{name}};
		}
	}
	
	my $json = to_json($jsonhash);
	return $json;

};

1;
