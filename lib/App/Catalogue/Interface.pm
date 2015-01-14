package App::Catalogue::Interface;

use Catmandu::Sane;
use Catmandu::Util qw(:array);
use Dancer ':syntax';
use Dancer::Request;
use App::Helper;

prefix '/myPUB' => sub {

	get '/search_researcher' => sub {

		my $q;
		push @$q, params->{'ftext'};
		my $hits = h->search_researcher({q => $q});

		to_json($hits->{hits});
	};

	get '/authority_user/:id' => sub {
		my $person = h->getPerson(params->{id});
		to_json $person;
	};

	get '/autocomplete_alias/:alias' => sub {
		my $term = params->{'alias'} || "";
		my $alias = h->authority_user->select("alias", $term)->to_array;
		#return to_dumper $alias;
		if ($alias->[0]) {
			return to_json({ok => 0});
		} else {
			return to_json({ok => 1});
		}
	};

	get '/autocomplete_connect' => sub {
		my $term = params->{'term'} || "";
		my $q = params->{'q'} || "";

		if($term ne "" and $q eq ""){
			if(session->{role} ne "user"){
				$q = "title=" . $term . "* OR person=" . $term . "*";
			}
			else {
				$q = "title=" . $term . "*";
			}
		}
		elsif($term ne "" and $q ne "") {
			$q = $q . " AND " . $term . "*";
		}

		my $p = {limit => 1000, sort => "title,,0"};
		push @{$p->{q}}, $q;

		my $hits = h->search_publication($p);

		my $jsonhash = [];
		
		if($hits->{total}){
        	$hits->each( sub{
        		my $hit = $_[0];
        		if($hit->{title} && $hit->{year}){
        			my $label = "$hit->{title} ($hit->{year}";
        			my $author = $hit->{author} || $hit->{editor} || [];
        			if($author && $author->[0]->{first_name} && $author->[0]->{last_name}){
        				$label .= ", " .$author->[0]->{first_name} . " " . $author->[0]->{last_name} .")";
        			}
        			else{
        				$label .= ")";
        			}
        			push @$jsonhash, {id => $hit->{_id}, label => $label, title => "$hit->{title}"};
        		}
        	});
        	my $json = to_json($jsonhash);
        	return $json;
        }
	};

	get '/autocomplete_hierarchy' => sub {
		return unless params->{'term'};

		my $fmt = params->{fmt} || "autocomplete";
		my $type = params->{type} || "department";
		my $q;
		if(params->{'term'} =~ /[äöüß]/){
			$q = "name=" . lc params->{'term'};
		}
		else {
			$q = "name=" . lc params->{'term'} . "*";
		}
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

		my $json = to_json($jsonhash);
		return $json;

	};

};

1;
