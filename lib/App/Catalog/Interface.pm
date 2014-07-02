package App::Catalog::Interface;

use Catmandu::Sane;
use Catmandu::Util qw(:array);
use Dancer ':syntax';
use Dancer::Request;
use App::Catalog::Helper;

get '/search_researcher' => sub {
	
	my $q = params->{'ftext'};
	my $hits = h->search_researcher({q => $q});
	
	to_json($hits->{hits});
	
};

get '/autocomplete_hierarchy' => sub {
	my $q = params->{'term'} || "";
	my $fmt = params->{fmt} || "autocomplete";
	my $type = params->{type} || "department";
	$q = "name=" . $q . "*" if ($q ne "");
	my $hits;
	
	if($type eq "department"){
		$hits = h->search_department({q => $q, limit => 1000, sort => "name,,0"});
	}
	elsif($type eq "project"){
		$hits = h->search_project({q => $q, limit => 1000});
	}
	#elsif($type eq "researchgroup"){
	#	$hits = h->search_researchgroup({q => $q});
	#}
	my $jsonhash = ();
	my $sorted;
	my $fullsort;
	
	#to_dumper($hits);
	
	if($fmt eq "autocomplete"){
		foreach (@{$hits->{hits}}){
			my $label = "";
			
			if($_->{tree}){				
				foreach my $dep (@{$_->{tree}}){
					next if $dep eq $_->{_id};
					my $info = h->getDepartment($dep);
					my $name = $info->{name};
					$label .= $name . " | ";
				}
				$label =~ s/ \| $//g;
				$label =  "(" . $label . ")" if $label ne "";
			}
			
			$label = $_->{name} . " " . $label;
			
			$label =~ s/"/\\"/g;
			push @$jsonhash, {id => $_->{_id}, label => $label};
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
