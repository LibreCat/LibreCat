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

get '/authority_user/:id' => sub {
	my $id = params->{'id'};
	my $user = h->authority_user->get($id);
	my $admin = h->authority_admin->get($id);
	my @fields = qw(full_name last_name first_name email department super_admin reviewer dataManager delegate);
	map {
		$user->{$_} = $admin->{$_};
	} @fields;
	to_json($user);
};

get '/autocomplete_connect' => sub {
	my $q = params->{'term'} || "";

	if($q ne ""){
		if(session->{role} ne "user"){
			$q = "title=" . $q . "* OR person=" . $q . "*",
		}
		else {
			$q = "title=" . $q . "*";
		}
	}


	my $hits = h->search_publication({q => $q, limit => 1000, sort => "title,,0"});
	my $jsonhash;

	foreach my $hit (@{$hits->{hits}}){
		my $label = "$hit->{title} ($hit->{year}, ";
		if(!$hit->{author} and $hit->{editor}){
#			foreach my $editor (@{$hit->{editor}}){
#				$label .= $editor->{first_name} . " " . $editor->{last_name} . ", ";
#			}
			$label .= $hit->{editor}->[0]->{first_name} . " " . $hit->{editor}->[0]->{last_name};
			$label .= ", 1st ed.)";
		}
		elsif($hit->{author}){
#			foreach my $author (@{$hit->{author}}){
#				$label .= $author->{first_name} . " " . $author->{last_name} . ", ";
#			}
#			$label =~ s/, $//g;
			$label .= $hit->{author}->[0]->{first_name} . " " . $hit->{author}->[0]->{last_name};
			$label .= ", 1st auth.)",
		}
		else{
			$label =~ s/, $/)/g;
		}

		push @$jsonhash, {id => $hit->{_id}, label => $label, title => "$hit->{title}"};
	}

	my $json = to_json($jsonhash);
	return $json;
};

get '/autocomplete_hierarchy' => sub {
	return unless params->{'term'};

    my $fmt = params->{fmt} || "autocomplete";
	my $type = params->{type} || "department";
	my $q = "name=" . lc params->{'term'} . "*";
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
			$label =~ s/\s+$//g;
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
