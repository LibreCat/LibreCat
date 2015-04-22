package App::Catalogue::Interface;

use Catmandu::Sane;
use Catmandu::Util qw/:array/;
use Dancer qw/:syntax/;
use Dancer::Request;
use App::Helper;
use Citation;

prefix '/myPUB' => sub {

	get '/search_researcher' => sub {
		my $q;
		push @$q, params->{'ftext'};

		to_json h->search_researcher({q => $q})->{hits};
    };

	get '/authority_user/:id' => sub {
		to_json h->getPerson(params->{id});
	};

	get '/autocomplete_alias/:alias' => sub {
		my $term = params->{'alias'} || "";
		my $alias = h->authority->select("alias", $term)->to_array;

        return to_json {ok => $alias->[0] ? 0 : 1};
	};

	get '/autocomplete_hierarchy' => sub {
		return unless params->{'term'};

		my $fmt = params->{fmt} || "autocomplete";
		my $type = params->{type} || "department";
		my $q;
		my @query;
		my @terms = split(' ', params->{term});
		foreach my $term (@terms){
			push @query, "name=" . lc $term if $term =~ /[äöüß]/;
			push @query, "name=" . lc $term . "*" if $term !~ /[äöüß]/;
		}
#		if(params->{'term'} =~ /[äöüß]/){
#			$q = "name=" . lc params->{'term'};
#		}
#		else {
#			$q = "name=" . lc params->{'term'} . "*";
#		}
		$q = join(" AND ", @query);
		my $hits;

		if($type eq "department"){
			$hits = h->search_department({q => $q, limit => 1000, sort => "name,,0"});
		}
		elsif($type eq "project"){
			$hits = h->search_project({q => $q, limit => 1000});
		}
#		elsif($type eq "researchgroup"){
#			$hits = h->search_researchgroup({q => $q});
#		}
		my $jsonhash = ();
		my $sorted;
		my $fullsort;

		if($fmt eq "autocomplete"){
			if($hits->{total} > 0){
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
					$label =~ s/\s+$//g;
					push @$jsonhash, {id => $_->{_id}, label => $label};
				}
			}
			else {
				$jsonhash = [];
			}
		}
		else{
			foreach (@{$hits->{hits}}){
				push @$jsonhash, {id => $_->{_id}, label => $_->{name}};
			}
		}

		return to_json($jsonhash);
	};

};

get '/livecitation' => sub {
    my $params = params;
    my $debug = $params->{debug} ? "debug" : "no_debug";
    unless ($params->{id} and $params->{style}) {
        return "'id' and 'style' needed.";
    }

    my $pub = h->publication->get($params->{id});

    my $response = Citation::index_citation_update($pub, 1, $debug, [$params->{style}]);

    if($debug eq "debug"){
    	return to_dumper $response;
    }
    else {
    	utf8::decode($response);
    	template "websites/livecitation", {citation => $response};
    }
};

1;
