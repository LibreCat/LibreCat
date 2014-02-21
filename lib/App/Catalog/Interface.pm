package App::Catalog::Interface;

use Catmandu::Sane;
use Catmandu::Util qw(:array);
use Dancer ':syntax';
use Dancer::Request;
use App::Catalog::Helper;

get '/myPUB/settings_update' => sub {
	#my $params = params;
	#my $id = "86212";
	my $id = params->{id} ? params->{id} : "73476";

	my $personInfo = h->getPerson($id);
	my $personStyle;
	my $personSort;
	if($personInfo->{stylePreference} and $personInfo->{stylePreference} =~ /(\w{1,})\.(\w{1,})/){
		if(array_includes(h->config->{lists}->{styles},$1)){
			$personStyle = $1 unless $1 eq "pub";
		}
		$personSort = $2;
	}
	elsif($personInfo->{stylePreference} and $personInfo->{stylePreference} !~ /\w{1,}\.\w{1,}/){
		if(array_includes(h->config->{lists}->{styles},$personInfo->{stylePreference})){
			$personStyle = $personInfo->{stylePreference} unless $personInfo->{stylePreference} eq "pub";
		}
	}
	
	if($personInfo->{sortPreference}){
		$personSort = $personInfo->{sortPreference};
	}
	
	my $style = params->{style} || $personStyle || h->config->{store}->{default_fd_style};
	delete(params->{style}) if params->{style};
	
	my $sort = params->{'sort'} || $personSort || "";
	
	$personInfo->{stylePreference} = $style;
	$personInfo->{sortPreference} = $sort if $sort ne "";
	my ($sec,$min,$hour,$day,$mon,$year) = localtime(time);
	$personInfo->{dateLastChanged} = sprintf("%04d-%02d-%02dT%02d:%02d:%02d", 1900+$year, 1+$mon, $day, $hour, $min, $sec);
	h->authority->add($personInfo);
	
	redirect '/myPUB/';
};

post '/myPUB/authorid_update' => sub {
	#my $id = params->{id};
	#my $id = "86212";
	my $id = params->{id} ? params->{id} : "73476";
	my $personInfo = h->getPerson($id);
	$personInfo->{googleScholarId} = params->{googlescholar} ? params->{googlescholar} : "";
	$personInfo->{researcherId} = params->{researcherid} ? params->{researcherid} : "";
	$personInfo->{authorClaim} = params->{authorclaim} ? params->{authorclaim} : "";
	$personInfo->{scopusId} = params->{scopusid} ? params->{scopusid} : "";
	$personInfo->{orcidId} = params->{orcid} ? params->{orcid} : "";
	$personInfo->{githubId} = params->{githubid} ? params->{githubid} : "";
	$personInfo->{arxivId} = params->{arxivid} ? params->{arxivid} : "";
	$personInfo->{inspireId} = params->{inspireid} ? params->{inspireid} : "";
	my ($sec,$min,$hour,$day,$mon,$year) = localtime(time);
	$personInfo->{dateLastChanged} = sprintf("%04d-%02d-%02dT%02d:%02d:%02d", 1900+$year, 1+$mon, $day, $hour, $min, $sec);
	my $bag = h->authority->add($personInfo);
	
	redirect '/myPUB/';
};
	
get '/myPUB/search_researcher' => sub {
	my $q = params->{'ftext'};
	my $hits = h->search_researcher({q => $q});
		
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

get '/myPUB/autocomplete_hierarchy' => sub {
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
