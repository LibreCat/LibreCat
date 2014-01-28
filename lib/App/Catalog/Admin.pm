package App::Catalog::Admin;

use Catmandu::Sane;
use Dancer ':syntax';
use Dancer::Request;
use App::Catalog::Helper;

sub handle_request {
	my ($par) = @_;
	my $p;
	my $query = $par->{q};
	my $id = $par->{bisId};
	$p->{limit} = $par->{limit};
	
	my $personInfo = h->getPerson($id);
	
	my $facets = {
        coAuthor => {terms => {field => 'author.personNumber', size => 100, exclude => [$id]}},
        coEditor => {terms => {field => 'editor.personNumber', size => 100, exclude => [$id]}},
        openAccess => {terms => {field => 'file.openAccess', size => 10}},
        qualityControlled => {terms => {field => 'qualityControlled', size => 1}},
        popularScience => {terms => {field => 'popularScience', size => 1}},
        nonlu => {terms => {field => 'isNonLuPublication', size => 1}},
        hasMedline => {terms => {field => 'hasMedline', size => 1}},
        hasArxiv => {terms => {field => 'hasArxiv', size => 1}},
        hasInspire => {terms => {field => 'hasInspire', size => 1}},
        hasIsi => {terms => {field => 'hasIsi', size => 1}},
    };
    $p->{facets} = $facets;
	
	my $rawquery = $query;
    my $doctypequery = "";
    my $publyearquery = "";
    
    # separate handling of publication types (for separate facet)
    if(params->{publicationtype} and ref params->{publicationtype} eq 'ARRAY'){
    	my $tmpquery = "";
    	foreach (@{params->{publicationtype}}){
    		$tmpquery .= "documenttype=" . $_ . " OR ";
    	}
    	$tmpquery =~ s/ OR $//g;
    	$query .= " AND (" . $tmpquery . ")";
    	$doctypequery .= " AND (" . $tmpquery . ")";
    }
    elsif (params->{publicationtype} and ref params->{publicationtype} ne 'ARRAY'){
    	$query .= " AND documenttype=". params->{publicationtype};
    	$doctypequery .= " AND documenttype=". params->{publicationtype};
    }
    
    #separate handling of publishing years (for separate facet)
    if(params->{publishingyear} and ref params->{publishingyear} eq 'ARRAY'){
    	my $tmpquery = "";
    	foreach (@{params->{publishingyear}}){
    		$tmpquery .= "publishingyear=" . $_ . " OR ";
    	}
    	$tmpquery =~ s/ OR $//g;
    	$query .= " AND (" . $tmpquery . ")";
    	$publyearquery .= " AND (" . $tmpquery . ")";
    }
    elsif (params->{publishingyear} and ref params->{publishingyear} ne 'ARRAY'){
    	$query .= " AND publishingyear=". params->{publishingyear};
    	$publyearquery .= " AND publishingyear=". params->{publishingyear};
    }
    
    $p->{q} = $query;
    $p->{facets} = $facets;
    
    my $hits = h->search_publication($p);
    
    my $d = {q => $rawquery.$publyearquery, limit => 1, facets => {documentType => {terms => {field => 'documentType', size => 30}}}};
    my $dochits = h->search_publication($d);
    $hits->{dochits} = $dochits;
    
    my $y = {q => $rawquery.$doctypequery, limit => 1, facets => {year => {terms => {field => 'publishingYear', size => 100, order => 'reverse_term'}}}};
    my $yearhits = h->search_publication($y);
    $hits->{yearhits} = $yearhits;
	
	my $titleName;
	$titleName .= $personInfo->{givenName}." " if $personInfo->{givenName};
	$titleName .= $personInfo->{surname}." " if $personInfo->{surname};
	
	if($titleName){
		$hits->{personPageTitle} = "Publications " . $titleName;
	}
	
	$hits->{sbcatId} = $par->{sbcatId};
	$hits->{bisId} = $par->{bisId};
	$hits->{style} = $par->{style};
	
	template 'admin.tt', $hits;
} 
    
get '/myPUB' => sub {
	forward '/myPUB/86212';
};
	
get '/myPUB/add' => sub {
	my $person = h->getPerson("86212");
	my $departments = $person->{affiliation};
	template 'backend/forms/researchData.tt', {recordOId => "123456789", departments => $departments};#, file => [{fileOId => 1, fileName => "file", accessLevel => "admin", dateLastUploaded => "2014-01-10", isUploadedBy => {login => "kohorst"}}]};
};
	
get qr{/myPUB/(\d{1,})/*} => sub {
	my ($id) = splat;
	my $personInfo = h->getPerson($id);
	my $sbcatId = $personInfo->{sbcatId};
		
	my $p = {
		q => "person=$id AND hide<>$id",
		limit => h->config->{store}->{maximum_page_size},
	};
	#my $hits = h->search_publication($p);
		
	$p->{sbcatId} = $sbcatId if $sbcatId;
	$p->{bisId} = $id;
	my $personStyle;
	my $personSort;
	if($personInfo->{stylePreference} and $personInfo->{stylePreference} =~ /(\w{1,})\.(\w{1,})/){
		$personStyle = $1;
		$personSort = $2;
	}
	$p->{style} = $personStyle || "pub";
	#template 'admin.tt', $hits;
	handle_request($p);
};

get qr{/myPUB/hidden/*} => sub {
	
	my $id = "86212";
	my $style = params->{style} || "pub";
	my $p = {
		q => "person=$id AND hide=$id",
		facets => "",
		limit => params->{limit} || h->config->{store}->{maximum_page_size},
		start => params->{start} || 0,
		style => $style,
		id => $id,
	};
	
	handle_request($p);
};

get '/myPUB/update' => sub {
	template 'admin_update';
};

get '/myPUB/accounts' => sub {
	template 'accounts'
};

get '/myPUB/curate' => sub {
	template 'curate';
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
