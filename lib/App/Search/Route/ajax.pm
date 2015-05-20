package App::Search::Route::ajax;

=head1 NAME

App::Search::Route::ajax - handles routes for  asynchronous requests

=cut

use Catmandu::Sane;
use Catmandu::Util qw(join_path);
use Dancer qw/:syntax/;
use Dancer::Plugin::Ajax;
use App::Helper;

=head2 AJAX /metrics/:id

Web of Science 'Times Cited' information

=cut
ajax '/metrics/:id' => sub {
    my $metrics = h->get_metrics('wos', params->{id});
    return to_json {
        times_cited => $metrics->{times_cited},
        citing_url => $metrics->{citing_url},
    };
};

=head2 AJAX /thumbnail/:id

Thumbnail for frontdoor

=cut
ajax '/thumbnail/:id' => sub {
    my $path = h->get_file_path(params->{id});
    my $thumb = join_path($path, 'thumbnail.png');
    if ( -e $thumb ) {
        send_file $thumb,
            system_path  => 1,
            content_type => 'image/png';
    } else {
        #status 'not_found';
        send_file join_path(h->config->{appdir},"public/images/bookDummy.png"),
            system_path => 1,
            content_type => 'image/png';
    }
};

ajax '/citation/:id/:fmt' => sub {
    my $pub = h->publication->get(params->{id});

    my $out = h->export_publication($pub, params->{fmt},1);
    utf8::decode($out);
 
    to_json {
        cit => $out,
    };
};

1;

__END__

ajax '/search_researcher' => sub {
    my $q;
	push @$q, params->{'ftext'};

	to_json h->search_researcher({q => $q})->{hits};
};

ajax '/authority_user/:id' => sub {
	to_json h->getPerson(params->{id});
};

ajax '/getalias/:alias' => sub {
	my $term = params->{'alias'} || "";
	my $alias = h->authority->select("alias", $term)->to_array;

    to_json {ok => $alias->[0] ? 0 : 1};
};

	get '/autocomplete_hierarchy' => sub {
		return unless params->{'term'};

#		my $fmt = params->{fmt} || "autocomplete";
		my $type = params->{type} || "department";
		my $q;
		my @query;
		my @terms = split(' ', params->{term});

		foreach my $term (@terms){
			push @query, "name=" . lc $term if $term =~ /[äöüß]/;
			push @query, "name=" . lc $term . "*" if $term !~ /[äöüß]/;
		}

		$q = join(" AND ", @query);
		my $hits;

		if($type eq "department"){
			$hits = h->search_department({q => $q, limit => 10, sort => "name,,0"});
		}
		elsif($type eq "project"){
			$hits = h->search_project({q => $q, limit => 10});
		}
		my $jsonhash = ();
		my $sorted;
		my $fullsort;

#		if($fmt eq "autocomplete"){
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
		# }
		# else{
		# 	foreach (@{$hits->{hits}}){
		# 		push @$jsonhash, {id => $_->{_id}, label => $_->{name}};
		# 	}
		# }

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
