package App::Helper::Helpers;

use Catmandu::Sane;
use Catmandu qw(:load export_to_string);
use Catmandu::Util qw(:is :array :human trim);
use Catmandu::Fix qw /expand/;
use Dancer qw(:syntax vars params request);
use Sys::Hostname::Long;
use Template;
use Moo;
use POSIX qw(strftime);
use List::Util;
use Hash::Merge::Simple qw/merge/;
use JSON;

Catmandu->load(':up');

sub config {
	state $config = Catmandu->config;
}

sub bag {
	state $bag = Catmandu->store->bag;
}

sub publication {
	state $bag = Catmandu->store('search')->bag('publication');
}

sub project {
	state $bag = Catmandu->store('search')->bag('project');
}

sub award {
    state $bag = Catmandu->store('search')->bag('award');
}

sub researcher {
	state $bag = Catmandu->store('search')->bag('researcher');
}

sub department {
	state $bag = Catmandu->store('search')->bag('department');
}

sub authority_user {
    state $bag = Catmandu->store('authority')->bag('user');
}

sub authority_admin {
	state $bag = Catmandu->store('authority')->bag('admin');
}

sub authority_department {
	state $bag = Catmandu->store('authority')->bag('department');
}

sub toolkit {
	state $bag = Catmandu->store('toolkit')->bag;
}

sub string_array {
	my ($self, $val) = @_;
	return [ grep { is_string $_ } @$val ] if is_array_ref $val;
	return [ $val ] if is_string $val;
	[];
}

sub nested_params {
	my ($self, $params) = @_;

    foreach my $k (keys %$params) {
        unless (defined $params->{$k}) {
            delete $params->{$k};
            next;
        }
        delete $params->{$k} if ($params->{$k} =~ /^$/);
    }
	my $fixer = Catmandu::Fix->new(fixes => ["expand()"]);
    return $fixer->fix($params);
}

sub extract_params {
	my ($self, $params) = @_;
	$params ||= params;
	my $p = {};
	return $p if ref $params ne 'HASH';
	$p->{start} = $params->{start} if is_natural $params->{start};
	$p->{limit} = $params->{limit} if is_natural $params->{limit};

	$p->{q} = $self->string_array($params->{q});

	my $cql = $params->{cql_query} ||= '';

	if ($cql) {
		my $deletedq;

		if(@$deletedq = ($cql =~ /((?=AND |OR |NOT )?[0-9a-zA-Z]+\=\s|(?=AND |OR |NOT )?[0-9a-zA-Z]+\=$)/g)){
			$cql =~ s/((AND |OR |NOT )?[0-9a-zA-Z]+\=\s|(AND |OR |NOT )?[0-9a-zA-Z]+\=$)/ /g;
		}
		$cql =~ s/^\s*(AND|OR)//g;
		$cql =~ s/(NOT )(.*?)=/$2<>/g;
		$cql =~ s/(NOT )([^=]*?)/basic<>$2/g;
		$cql =~ s/(?<!")\b([^\s]+)\b, \b([^\s]+)\b(?!")/"$1, $2"/g;
		$cql =~ s/^\s+//; $cql =~ s/\s+$//; $cql =~ s/\s{2,}/ /;
		if ($cql !~ /^("[^"]*"|'[^']*'|[0-9a-zA-Z]+(=| ANY | ALL | EXACT )"[^"]*")$/ and $cql !~ /^(([0-9a-zA-Z]+\=(?:[0-9a-zA-Z\-\*]+|"[^"]*"|'[^']*')+\**(?<!AND)(?<!OR)(?<!ANY)(?<!ALL)(?<!EXACT)|"[^"]*"|'[^']*') (AND|OR) ([0-9a-zA-Z]+\=(?:[0-9a-zA-Z\-\*]+|"[^"]*"|'[^']*')+\**(?<!AND)(?<!OR)|"[^"]*"|'[^']*'))$/ and $cql !~ /^(([0-9a-zA-Z]+( ANY | ALL | EXACT )"[^"]*"|"[^"]*"|'[^']*'|[0-9a-zA-Z]+\=(?:[0-9a-zA-Z\-\*]+|"[^"]*"|'[^']*')+\**(?<!AND)(?<!OR))( (AND|OR) (([0-9a-zA-Z]+( ANY | ALL | EXACT )"[^"]*")|"[^"]*"|'[^']*'|[0-9a-zA-Z]+\=(?:[0-9a-zA-Z\-\*]+|"[^"]*"|'[^']*')+\**))*)$/) {
			$cql =~ s/((?:(?:(?:[0-9a-zA-Z\=]+(?<!AND)(?<!OR)|"[^"]*"|'[^']*') (?:AND|OR) )+(?:[0-9a-zA-Z\=]+(?<!AND)(?<!OR)|"[^"]*"|'[^']*'))|[0-9a-zA-Z\=]+(?<!AND)(?<!OR)|"[^"]*"|'[^']*')\s(?!AND )(?!OR )("[^"]*"|'[^']*'|.*?)/$1 AND $2/g;
		}
		push @{$p->{q}}, lc $cql;
	}

	#push @{$p->{q}}, $params->{text} if $params->{text};
	($params->{text} =~ /^".*"$/) ? (push @{$p->{q}}, $params->{text}) : (push @{$p->{q}}, join(" AND ",split(/ |-/,$params->{text}))) if $params->{text};

	# autocomplete functionality
	if($params->{term}){
		my $search_terms = join("* AND ", split(" ",$params->{term})) . "*";
		push @{$p->{q}}, "title=(" . $search_terms . ") OR person=(" . $search_terms . ") OR id=(" . $search_terms . ")";
		$p->{fmt} = $params->{fmt};
	}
	else {
		my $formats = $self->config->{exporter}->{publication};
		$p->{fmt} = ($params->{fmt} && $formats->{$params->{fmt}})
		? $params->{fmt} : 'html';
	}

	$p->{style} = $params->{style} if $params->{style};
	$p->{sort} = $self->string_array($params->{sort});
	$p->{ttype} = $params->{ttype} if $params->{ttype};

	$p;
}

sub get_sort_style {
	my ($self, $param_sort, $param_style, $id) = @_;
	my $user = $self->getPerson( $id || Dancer::session->{personNumber} );
	my $return;
	$param_sort = undef if ($param_sort eq "" or (ref $param_sort eq "ARRAY" and !$param_sort->[0]));
	$param_style = undef if $param_style eq "";
	# set default values - to be overridden by more important values
	my $style = $param_style || $user->{style} || $self->config->{store}->{default_style};
	my $sort;
	my $sort_backend;
	if($param_sort){
		$param_sort = [$param_sort] if ref $param_sort ne "ARRAY";
		foreach my $s (@{$param_sort}){
			push @$sort, $s;
			push @$sort_backend, $s;
		}
	}
	elsif($user->{'sort'}){
		foreach my $s (@{$user->{'sort'}}){
			push @$sort, $s;
			push @$sort_backend, $s;
		}
	}
	else{
		foreach my $s (@{$self->config->{store}->{default_sort}}){
			push @{$sort}, $s;
		}
		foreach my $s (@{$self->config->{store}->{default_sort_backend}}){
			push @{$sort_backend}, $s;
		}
	}

	$return->{'sort'} = $sort;
	$return->{sort_backend} = $sort_backend;
	$return->{user_sort} = $user->{'sort'} if $user->{'sort'};
	$return->{user_style} = $user->{style} if $user->{style};
	$return->{default_sort} = $self->config->{store}->{default_sort};
	$return->{default_sort_backend} = $self->config->{store}->{default_sort_backend};

	# see if style param is set
	if(array_includes($self->config->{lists}->{styles},$style)){
		$return->{style} = $style;
	}

	foreach my $key (keys %$return){
		my $ref = ref $return->{$key};

    	if($ref eq "ARRAY"){
    		if(!$return->{$key}->[0]){
    			delete $return->{$key};
    		}
    	}
    	elsif($ref eq "HASH"){
    		if(!%{$return->{$key}}){
    			delete $return->{$key};
    		}
    	}
    	else{
    		if($return->{$key} and $return->{$key} eq ""){
    			delete $return->{$key};
    		}
    	}
	}

	#my $usermongo_eq_currentsort = 0;
	#my $currentsort_eq_default = 0;
	$return->{sort_eq_usersort} = 0;
	$return->{sort_eq_usersort} = is_same($user->{'sort'}, $return->{'sort_backend'}) if $user->{'sort'};
	$return->{sort_eq_default} = 0;
	$return->{sort_eq_default} = is_same($return->{'sort_backend'}, $self->config->{store}->{default_sort_backend});

	$return->{style_eq_userstyle} = 0;
	$return->{style_eq_userstyle} = ($user->{style} and $user->{style} eq $return->{style}) ? 1 : 0;
	$return->{style_eq_default} = 0;
	$return->{style_eq_default} = ($return->{style} eq $self->config->{store}->{default_style}) ? 1 : 0;
#	if(($return->{user_style} and $return->{style} eq $return->{user_style}) or (!$return->{user_style} and $return->{style} eq $self->config->{store}->{default_style})){
#		$return->{style_up_to_date} = 1;
#	}

	return $return;
}

sub now {
	my $now = strftime($_[0]->config->{time_format}, gmtime(time));
	return $now;
}

sub pretty_byte_size {
	my ($self, $number) = @_;
	return human_byte_size($number);
}

sub generate_urn {
    my ($self, $prefix, $id) = @_;
    my $nbn = $prefix . $id;
    my $weighting  = ' 012345678 URNBDE:AC FGHIJLMOP QSTVWXYZ- 9K_ / . +#';
    my $faktor     = 1;
    my $productSum = 0;
    my $lastcifer;
    foreach my $char ( split //, uc($nbn) ) {
        my $weight = index( $weighting, $char );
        if ( $weight > 9 ) {
            $productSum += int( $weight / 10 ) * $faktor++;
            $productSum += $weight % 10 * $faktor++;
        }
        else {
            $productSum += $weight * $faktor++;
        }
        $lastcifer = $weight % 10;
    }
    return $nbn . ( int( $productSum / $lastcifer ) % 10 );
}

sub is_marked {
	my ($self, $id) = @_;
	my $marked = Dancer::session 'marked';
	return Catmandu::Util::array_includes($marked, $id);
}

sub getPublication {
	$_[0]->publication->get($_[1]);
}

sub getPerson {
	my $user;
	my $admin;
	if($_[1] and $_[1] =~ /\d{1,}/){
		$user = $_[0]->authority_user->get($_[1]);
		$admin = $_[0]->authority_admin->get($_[1]);
		return merge ( $admin, $user );
	}
}

sub getAccount {
	if ($_[1]) {
		$_[0]->authority_admin->select("login", $_[1])->to_array;
	}
}

sub getDepartment {
	if($_[1] =~ /\d{1,}/){
		$_[0]->authority_department->get($_[1]);
	}
	elsif($_[1] ne "") {
		$_[0]->authority_department->select("name_lc", lc $_[1])->to_array;
	}
	else{
		$_[0]->authority_department->to_array;
	}
}

sub getToolkit {
	$_[0]->toolkit->get($_[1]);
}

sub get_list {
	my $list = $_[1];
	my $map;
	$map = config->{lists}{$list};
	$map;
}

sub get_relation {
	my ($self, $list, $relation) = @_;
	my $map;
	$map = config->{lists}{$list};
	my %hash_list = map { $_->{relation} => $_ } @$map;
	$hash_list{$relation};
}

sub get_statistics {
	my ($self) = @_;
	my $stats;
	my $hits = $self->search_publication({q => ["status=public"]});
	my $reshits = $self->search_publication({q => ["status=public","(type=researchData OR type=dara)"]});
	my $oahits = $self->search_publication({q => ["status=public","fulltext=1","type<>researchData","type<>dara"]});
	my $disshits = $self->search_publication({q => ["status=public","type=bi*"]});
	my $people = $self->search_researcher();

	$stats->{publications} = $hits->{total} if $hits and $hits->{total};
	$stats->{researchdata} = $reshits->{total} if $reshits and $reshits->{total};
	$stats->{oahits} = $oahits->{total} if $oahits and $oahits->{total};
	$stats->{theseshits} = $disshits->{total} if $disshits and $disshits->{total};
	$stats->{pubpeople} = $people->{total} if $people and $people->{total};

	return $stats;
}

sub get_epmc {
	my ($self, $mod, $pmid) = @_;
	return {} unless $mod and $pmid;

	return Catmandu->store('metrics')->bag($mod)->get($pmid);
}

sub default_facets {
	return {
		author => {
			terms => {
				field   => 'author.id',
				size    => 20,
			}
		},
		editor => {
			terms => {
				field   => 'editor.id',
				size    => 20,
			}
		},
		open_access => { terms => { field => 'file.open_access', size => 1 } },
		quality_controlled => { terms => { field => 'quality_controlled', size => 2 } },
		popular_science => { terms => { field => 'popular_science', size => 2 } },
		extern => { terms => { field => 'extern', size => 2 } },
		status => { terms => { field => 'status', size => 8 } },
		year => { terms => { field => 'year', size => 100, order => 'reverse_term'} },
		type => { terms => { field => 'type', size => 25 } },
	};
}

sub sort_to_sru {
	my ($self, $sort) = @_;
	my $cql_sort;
	if($sort and ref $sort ne "ARRAY"){
		$sort = [$sort];
	}
	foreach my $s (@$sort){
		if($s =~ /(\w{1,})\.(asc|desc)/){
			$cql_sort .= "$1,,";
			$cql_sort .= $2 eq "asc" ? "1 " : "0 ";
		}
		elsif($s =~ /\w{1,},,(0|1)/){
			$cql_sort .= $s;
		}
	}
	$cql_sort = trim($cql_sort);
	return $cql_sort;
}

sub display_doctypes {
	my $map = config->{forms}{publicationTypes};
	my $doctype;
	$doctype = $map->{lc $_[1]}->{label};
	$doctype;
}

sub display_name_from_value {
	my ($self, $list, $value) = @_;
	my $map = $self->config->{lists}{$list};
	my $name;
	foreach my $m (@$map){
		if($m->{value} eq $value){
			$name = $m->{name};
		}
	}
	$name;
}

sub display_gs_doctypes {
	my $map = config->{forms}{display_gs_docs};
	my $doctype = $map->{lc $_[1]};
	$doctype;
}

sub host {
	return "http://" . hostname_long;
}

sub shost {
	return "https://" . hostname_long;
}

sub search_publication {
	my ($self, $p) = @_;
	my $sort = $self->sort_to_sru($p->{sort});
	my $cql = "";
	if ($p->{q}) {
		push @{$p->{q}}, "status<>deleted";
		$cql = join(' AND ', @{$p->{q}});
	} else {
		$cql = "status<>deleted";
	}

	my $hits = publication->search(
	    cql_query => $cql,
		sru_sortkeys => $sort,
		limit => $p->{limit} ||= $self->config->{store}->{default_page_size},
		start => $p->{start} ||= 0,
		facets => $p->{facets} ||= {},
	);

    foreach (qw(next_page last_page page previous_page pages_in_spread)) {
    	$hits->{$_} = $hits->$_;
    }

	return $hits;
}

sub export_publication {
	my ($self, $hits, $fmt) = @_;

	if ($fmt eq 'csl_json') {
		$self->export_csl_json($hits);
	}
	elsif($fmt eq 'autocomplete'){
		return $self->export_autocomplete_json($hits);
	}

	if ( my $spec = config->{exporter}->{publication}->{$fmt} ) {
		my $package = $spec->{package};
	   	my $options = $spec->{options} || {};

		$options->{style} = $hits->{style} || 'frontShortTitle';
	   	$options->{explinks} = params->{explinks};
	   	my $content_type = $spec->{content_type} || mime->for_name($fmt);
	   	my $extension = $spec->{extension} || $fmt;

	   	my $f = export_to_string( $hits, $package, $options );
	   	($fmt eq 'bibtex') && ($f =~ s/(\\"\w)\s/{$1}/g);
	   	return Dancer::send_file (
   	    	\$f,
	      	content_type => $content_type,
	      	filename     => "publications.$extension"
	   	);
	}
}

sub export_autocomplete_json {
	my ($self, $hits) = @_;
	my $jsonhash = [];
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

sub export_csl_json{
	my ($self, $hits) = @_;

	my $spec = config->{export}->{publication}->{csl_json};
	my $out;
	$hits->each(sub {
		my $id = $_[0]->{_id};
		my $csl = Citation::index_citation_update($id,0,'csl_json');
		push @$out, $csl;
		});

	my $f = export_to_string($out, $spec->{package}, $spec->{options} || {});
	return Dancer::send_file (
   	    \$f,
	    content_type => $spec->{content_type},
	    filename     => "publications.$spec->{extension}"
	   );
}

sub search_researcher {
	my ($self, $p) = @_;
	my $cql = "";
	if($p->{researcher_list}){
		push @{$p->{q}}, "publcount > 0";
	}

	$cql = join(' AND ', @{$p->{q}}) if $p->{q};

	my $hits = researcher->search(
	  cql_query => $cql,
	  limit => $p->{limit} ||= config->{store}->{maximum_page_size},
	  start => $p->{start} ||= 0,
	  sru_sortkeys => $p->{sorting} || "fullname,,1",
	);

	foreach (qw(next_page last_page page previous_page pages_in_spread)) {
    	$hits->{$_} = $hits->$_;
    }

    return $hits;
}

sub search_department {
	my ($self, $p) = @_;
	my $q;

	$q = $p->{q};

	my $hits = department->search(
	  cql_query => $q,
	  limit => $p->{limit} ||= 20,
	  start => $p->{start} ||= 0,
	);

	return $hits;
}

sub search_project {
	my ($self, $p) = @_;

	my $hits;
	$hits = project->search (
		cql_query => $p->{q},
		limit => $p->{limit} ||= config->{default_page_size},
	#	facets => $p->{facets} ||= {},
      	start => $p->{start} ||= 0,
       	sru_sortkeys => $p->{sorting} ||= "name,,1",
	);
	#foreach (qw(next_page last_page page previous_page pages_in_spread)) {
    #    $hits->{$_} = $hits->$_;
    #}
    return $hits;
}

sub get_file_path {
	my ($self, $pub_id) = @_;
	my $dest_dir = sprintf("%09d", $pub_id);
	my @dest_dir_parts = unpack 'A3' x 3, $dest_dir;
	$dest_dir = join '/', config->{upload_dir}, @dest_dir_parts;
	return $dest_dir;
}

sub uri_for {
    my ($self, $path, $uri_params) = @_;
    $uri_params ||= {};
    #$uri_params = {%{$self->embed_params}, %$uri_params};
    #my $uri = $self->host . $path . "?";
    my $uri = $path . "?";
    foreach (keys %{ $uri_params }) {
		$uri .= "$_=$uri_params->{$_}&";
    }
    $uri =~ s/&$//; #delete trailing "&"
    $uri;
}

sub newuri_for {
	my ($self, $path, $uri_params, $passedparam) = @_;
	my $passed_key; my $passed_value;
	foreach (keys %{$passedparam}){
		$passed_key = $_;
		$passed_value = $passedparam->{$_};
	}

	my $uri = $path . "?";

	$uri_params = () if $uri_params eq "";

	if(defined $uri_params->{$passed_key}){
		foreach my $urikey (keys %{$uri_params}){
			if ($urikey ne $passed_key){
				next if $urikey eq "start";
				if (ref $uri_params->{$urikey} eq 'ARRAY'){
					foreach (@{$uri_params->{$urikey}}){
						$uri .= "$urikey=$_&";
					}
				}
				elsif ($uri_params->{$urikey}) {
					$uri .= "$urikey=$uri_params->{$urikey}&";
				}
			}
			else { # $urikey eq $passed_key
				if($passed_key eq "person" or $passed_key eq "author" or $passed_key eq "editor" or $passed_key eq "publicationtype" or $passed_key eq "publishingyear" or $passed_key eq "sort"){
					if (ref $uri_params->{$urikey} eq 'ARRAY'){
						foreach (@{$uri_params->{$urikey}}){
							if($passed_value ne ""){
								if($passed_value !~ /^del_.*/ or ($passed_value =~ /^del_(.*)/ and $_ ne $1)){
									$uri .= "$urikey=$_&";
								}
							}

						}
					}
					else {
						$uri .= "$urikey=$uri_params->{$urikey}&" unless $passed_value eq "";
					}
					$uri .= "$passed_key=$passed_value&" unless $passed_value eq "" or $passed_value =~ /^del_.*/;
				}
				else {
					$uri .= "$passed_key=$passed_value&" unless $passed_value eq "";
				}
			}
		}
	}
	else {
		foreach my $urikey (keys %{$uri_params}){
			next if $urikey eq "start";
			if (ref $uri_params->{$urikey} eq 'ARRAY'){
				foreach (@{$uri_params->{$urikey}}){
					$uri .= "$urikey=$_&";
				}
			}
			elsif ($uri_params->{$urikey}){
				$uri .= "$urikey=$uri_params->{$urikey}&";
			}
		}
		$uri .= "$passed_key=$passed_value&";
	}

	$uri =~ s/&$//;
	$uri;
}

sub embed_params {
	my ($self) = @_;
    vars->{embed_params} ||= do {
    	my $p = {};
        for my $key (qw(embed hide_pagination hide_info hide_options)) {
            $p->{$key} = 1 if params->{$key};
        }
        for my $key (qw(style)) {
            $p->{$key} = params->{$key} if is_string(params->{$key});
        }
        $p;
    };
}

package App::Helper;

my $h = App::Helper::Helpers->new;

use Catmandu::Sane;
use Dancer qw(:syntax hook);
use Dancer::Plugin;

register h => sub { $h };

hook before_template => sub {

    $_[0]->{h} = $h;

};

register_plugin;

1;
