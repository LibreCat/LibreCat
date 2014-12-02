package App::Helper::Helpers;

use Catmandu::Sane;
use Catmandu qw(:load export_to_string);
use Catmandu::Util qw(:is :array trim);
use Catmandu::Fix qw /expand/;
use Dancer qw(:syntax vars params request);
use Sys::Hostname::Long;
use Template;
use Moo;
use POSIX qw(strftime);
use List::Util;
use Hash::Merge::Simple qw/merge/;

Catmandu->load(':up');

# easy config accessor
######################
sub config {
	state $config = Catmandu->config;
}

# helper functions for stores
#############################
sub bag {
	state $bag = Catmandu->store->bag;
}

sub publication {
	state $bag = Catmandu->store('search')->bag('publicationItem');
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

sub string_array {
	my ($self, $val) = @_;
	return [ grep { is_string $_ } @$val ] if is_array_ref $val;
	return [ $val ] if is_string $val;
	[];
}

sub sort_options {
	state $sort_options = do {
		my $sorts = $_[0]->config->{publication_sorts} || [];
		List::Util::reduce {
			$a->{"$b->{key}.$b->{order}"} = $b; $a;
		} +{}, @$sorts;
	};
}

#sub trim {
#	my ($self, $str) = @_;
#	$str =~ s/^\s+//;
#	$str =~ s/\s+$//;
#	return $str;
#}

# helper for params handling
############################
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
	$p->{text} = $params->{text} if $params->{text};

	# now $p->{q} is an arrayref
	push @{$p->{q}}, $params->{text} if $params->{text};

#	my $formats = keys %{ $self->config->{exporter}->{publication} };
#	$p->{fmt} = array_includes($formats, $params->{fmt}) ? $params->{fmt}
#		: $self->config->{default_fmt};

#	my $style = $params->{style} || = $self->config->{default_style};
#	my $styles = $self->config->{lists}->{styles};

#	$p->{style} = array_includes($styles, $params->{style}) ? $params->{style}
#			: $self->config->{store}->{default_style};

	my $sort = $self->string_array($params->{sort});
#	$sort = [ grep { exists $self->sort_options->{$_} } map { s/(?<=[^_])_(?=[^_])//g; lc $_ } split /,/, join ',', @$sort ];
#	$sort = [] if is_same $sort, $self->config->{default_publication_sort};
	$p->{sort} = $sort;

	$p;
}

sub get_sort_style {
	my ($self, $style, $sort) = @_;
	my $user = $self->getAccount( Dancer::session->{user} )->[0];
	my $return;
	
	# set default values - to be overriden by more important values
	my $return_style = $style || $user->{stylePreference} || $self->config->{store}->{default_style};
	my $return_sort = $sort || $user->{sortPreference} || $self->config->{store}->{default_sort};
	my $return_sort_backend = $sort || $user->{sortPreference} || $self->config->{store}->{default_sort_backend};
	
	$return_sort = [$return_sort] if(ref $return_sort ne "ARRAY");
	foreach my $s (@{$return_sort}){
		if($s =~ /(\w{1,})\.(\w{1,})/){
			my $sorting = "$1,,";
			$sorting .= $2 eq "asc" ? "1 " : "0 ";
			$return->{'sort'} .= $sorting;
		}
		else{
			$return->{'sort'} .= "$s,,0 ";
		}
	}
	$return_sort_backend = [$return_sort_backend] if(ref $return_sort_backend ne "ARRAY");
	foreach my $s (@{$return_sort_backend}){
		if($s =~ /(\w{1,})\.(\w{1,})/){
			my $sorting = "$1,,";
			$sorting .= $2 eq "asc" ? "1 " : "0 ";
			$return->{sort_backend} .= $sorting;
		}
		else{
			$return->{sort_backend} .= "$s,,0 ";
		}
	}
	$return->{'sort'} = trim($return->{'sort'});
	$return->{sort_backend} = trim($return->{sort_backend});
	
	# see if style param is set
	if(array_includes($self->config->{lists}->{styles},$return_style)){
		$return->{style} = $return_style;
	}
	
	return $return;
}

sub now {
	 my $now = strftime($_[0]->config->{time_format}, gmtime(time));
	 return $now;
}

sub generateURN {
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

sub getPerson {
	my $user;
	my $admin;
	if($_[1] and $_[1] =~ /\d{1,}/){
		$user = $_[0]->authority_user->get($_[1]);
		$admin = $_[0]->authority_admin->get($_[1]);
		return merge ( $admin, $user );
		#my @fields = qw(full_name last_name first_name email department super_admin reviewer data_manager delegate);
		#map {
		#	$user->{$_} = $admin->{$_};
		#} @fields;
		#$user;
	}
}

sub getAccount {
	if($_[1]){# and $_[1] =~ /\w{1,}/){
		$_[0]->authority_admin->select("login", $_[1])->to_array;
		#$_[0]->authority_admin->select("luLdapId", $_[1])->to_array;
	}
	#else {
	#	$_[0]->authority_admin->to_array;
	#}
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

sub get_list {
	my $list = $_[1];
	my $map;
	$map = config->{lists}{$list};
	$map;
}

# sub get_statistics {
# 	my ($self) = @_;
# 	my $stats;
# 	my $hits = $self->search_publication({q => ""});
# 	my $reshits = $self->search_publication({q => "", bag => "data"});
# 	my $oahits = $self->search_publication({q => "fulltext=1"});
# 	my $disshits = $self->search_publication({q => "documenttype=bi*"});
# 	my $people = $self->search_researcher({q => ""});
#
# 	$stats->{publications} = $hits->{total} if $hits and $hits->{total};
# 	$stats->{researchdata} = $reshits->{total} if $reshits and $reshits->{total};
# 	$stats->{oahits} = $oahits->{total} if $oahits and $oahits->{total};
# 	$stats->{theseshits} = $disshits->{total} if $disshits and $disshits->{total};
# 	$stats->{pubpeople} = $people->{total} if $people and $people->{total};
#
# 	return $stats;
#
# }

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
		quality_controlled => { terms => { field => 'quality_controlled', size => 1 } },
		popular_science => { terms => { field => 'popular_science', size => 1 } },
		extern => { terms => { field => 'extern', size => 1 } },
		status => { terms => { field => 'status', size => 8 } },
		year => { terms => { field => 'year'} },
		type => { terms => { field => 'type', size => 25 } },
	};
}

sub display_doctypes {
	my $map = config->{forms}{publicationTypes};
	my $doctype = $map->{lc $_[1]}->{label};
	$doctype;
}

sub display_gs_doctypes {
	my $map = config->{forms}{display_gs_docs};
	my $doctype = $map->{lc $_[1]};
	$doctype;
}

sub host {
	return "http://" . hostname_long . ":3000";
}

sub shost {
	return "https://" . hostname_long;
}

sub search_publication {
	my ($self, $p) = @_;
	my $sort = $p->{sort};
	my $cql = "";
	$cql = join(' AND ', @{$p->{q}}) if $p->{q};
	#return $cql;
	my $hits = publication->search(
	    cql_query => $cql,
		sru_sortkeys => $sort,
		limit => $p->{limit} ||= config->{default_page_size},
		start => $p->{start} ||= 0,
		facets => $p->{facets} ||= {},
	);

    foreach (qw(next_page last_page page previous_page pages_in_spread)) {
    	$hits->{$_} = $hits->$_;
    }

	return $hits;
}

# sub return_publication {
# 	my ($self, $hits, $opts) = @_;
# 	if ( $opts->{fmt} eq 'html' ) {
# 		if ($opts->{ftyp}) {
# 			$tmpl .= "_". $par->{ftyp};
# 			header("Content-Type" => "text/plain") unless ($par->{ftyp} eq 'iframe' || $par->{ftyp} eq 'pln');
# 			$tmpl .= "_num" if ($par->{enum} and $par->{enum} eq "1");
# 			$tmpl .= "_numasc" if ($par->{enum} and $par->{enum} eq "2");
# 			template $tmpl, $hits;
# 		}
#
# 		if($limit == 1 && @{$hits->{hits}}[0]){
# 			@{$hits->{hits}}[0]->{style} = $style;
# 			@{$hits->{hits}}[0]->{marked} = @$marked;
# 			@{$hits->{hits}}[0]->{bag} = $hits->{bag};
# 			template "frontdoor/record.tt", @{$hits->{hits}}[0];
# 		} else {
# 			template $tmpl, $hits;
# 		}
# 	}
#
# }

sub search_researcher {
	my ($self, $p) = @_;
	my $q = $p->{q} ||= "";

	my $hits = researcher->search(
	  cql_query => $q,
	  limit => $p->{limit} ||= config->{store}->{maximum_page_size},
	  start => $p->{start} ||= 0,
	  #sru_sortkeys => $p->{sorting} || "full_name,,1",
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

sub embed_string {
	my ($self, $query, $bag, $id, $style, %params) = @_;
	my $embed;
	my $host = $_[0]->host();
	delete $params{splat};

	if(keys %params){
		# create a javaScript snipped for this list
		my $ftyp = '&ftyp=js';
		my $stylestring = "&style=";
		$stylestring .= $style if $style;

		my $sortstring = "";
		if($params{sort}){
			if (ref $params{sort} eq 'ARRAY'){
				foreach (@{$params{sort}}){
					$sortstring .= "&sort=$_";
				}
			}
			else{
				$sortstring = "&sort=$params{sort}";
			}
		}

		my $string1 = '&lt;div class="publ"&gt;&lt;script type="text/javascript" charset="UTF-8" src="' . $host . '/';
		if($bag eq "person"){
			$string1 .= "publication";
		}
		else {
			$string1 .= $bag;
		}

		$string1 .= '?q=';
		my $string2 = '"&gt;&lt;/script&gt;&lt;noscript&gt;&lt;a href="' . $host . '/';
		if($bag eq "person"){
			$string2 .= "publication";
		}
		else {
			$string2 .= $bag;
		}

		$string2 .= '?q=';
		my $string3 = '" target="_blank"&gt;';
		$string3 .= 'Pers&amp;ouml;nliche Publikationsliste &gt;&gt; / My Publication List &gt;&gt;' if $bag eq "person";
		$string3 .= 'Publikationsliste &gt;&gt; / Publication List &gt;&gt;' if $bag ne "person";
		$string3 .= '&lt;/a&gt;&lt;/noscript&gt;&lt;/div&gt;';

		$embed->{js} = $string1 . $query . $ftyp . $stylestring . $sortstring . $string2 . $query . $stylestring . $sortstring . $string3;
		$string1 = ""; $string2 = ""; $string3 = ""; $ftyp = "";


		# create an iFrame containing this list
		$ftyp = "&ftyp=iframe";
		$string1 = '&lt;iframe id="pubIFrame" name="pubIFrame" frameborder="0" width="726" height="300" src="' . $host . '/';
		if($bag eq "person"){
			$string1 .= "publication";
		}
		else {
			$string1 .= $bag;
		}
		$string1 .= '?q=';
		$string2 = '"&gt;&lt;/iframe&gt;';

		$embed->{iframe} = $string1 . $query . $ftyp . $stylestring . $sortstring . $string2;
		$string1 = ""; $string2 = "";


		# create a link to this page
		$string1 = '&lt;a href="' . $host . '/' . $bag;
		$string1 .= '/' . $id if $id;
		$string1 .= '?';
		$string2 = '"&gt;My Publication List&lt;/a&gt;';

		my $linkstring = $string1;
		foreach my $key (keys %params){
			next if $key eq 'splat';
			if(ref $params{$key} eq 'ARRAY'){
				foreach (@{$params{$key}}){
					$linkstring .= "$key=$_&";
				}
			}
			else {
				$linkstring .= "$key=$params{$key}&" if $params{$key};
			}
		}
		#$embed->{'modlink'} = $linkstring . $string2;
		$embed->{'link'} = $linkstring . $string2;
	}

	else {
		# create a javaScript snipped for this list
		my $ftyp = '&ftyp=js';
		my $stylestring = "&style=";
		$stylestring .= $style if $style;

		my $string1 = '&lt;div class="publ"&gt;&lt;script type="text/javascript" charset="UTF-8" src="' . $host . '/';
		if($bag eq "person"){
			$string1 .= "publication";
		}
		else{
			$string1 .= $bag;
		}
		$string1 .= '?q=';
		my $string2 = '"&gt;&lt;/script&gt;&lt;noscript&gt;&lt;a href="' . $host . '/';
		if($bag eq "person"){
			$string2 .= "publication";
		}
		else {
			$string2 .= $bag;
		}
		$string2 .= '?q=';
		my $string3 = '" target="_blank"&gt;';
		$string3 .= 'Pers&amp;ouml;nliche Publikationsliste &gt;&gt; / My Publication List &gt;&gt;' if $bag eq "person";
		$string3 .= 'Publikationsliste &gt;&gt; / Publication List &gt;&gt;' if $bag ne "person";
		$string3 .= '&lt;/a&gt;&lt;/noscript&gt;&lt;/div&gt;';

		$embed->{js} = $string1 . $query . $ftyp . $stylestring . $string2 . $query . $stylestring . $string3;
		$string1 = ""; $string2 = ""; $string3 = ""; $ftyp = "";


		# create an iFrame containing this list
		$ftyp = "&ftyp=iframe";
		$string1 = '&lt;iframe id="pubIFrame" name="pubIFrame" frameborder="0" width="726" height="300" src="' . $host . '/';
		if($bag eq 'person'){
			$string1 .= "publication";
		}
		else{
			$string1 .= $bag;
		}
		$string1 .= '?q=';
		$string2 = '"&gt;&lt;/iframe&gt;';

		$embed->{iframe} = $string1 . $query . $ftyp . $stylestring . $string2;
		$string1 = ""; $string2 = "";


		# create a link to this page
		$string1 = '&lt;a href="' . $host . '/person/'. $id;
		$string2 = '"&gt;My Publication List&lt;/a&gt;';

		$embed->{'link'} = $string1 . $string2;
	}

	return $embed;
}

sub clean_cql {
	my ($self, $query) = @_;
	my $cleancql = "";

	# Strip all leading and trailing whitespaces from full query
	$query =~ s/^\s+//; $query =~ s/\s+$//;

	# Remove incorrect modifiers directly after q=
	if($query =~ /^(AND|OR|NOT)(.*)/){
		my $tail = $2;
		$tail =~ s/^\s+//; $tail =~ s/\s+$//;
		$cleancql .= $tail;
	}
	else {
		$cleancql .= $query;
	}

	# Surround AND, OR and NOT with whitespaces
	$cleancql =~ s/(AND|OR|NOT)(\S.*)/$1 $2/;
	$cleancql =~ s/(.*\S)(AND|OR|NOT)/$1 $2/;

	return $cleancql;
}

sub make_cql {
	my ($self, $p) = @_;

	my $query;
	if($p->{q}){
		return $p->{q};
	} else {
		if($p->{person} and $p->{person} ne ""){
			$query .= "person=" . $p->{person} . " AND hide<>" . $p->{person};
		}
		elsif($p->{department} and $p->{department} ne ""){
			$query .= "department=" . $p->{department};
		}


		if($p->{author} and ref $p->{author} eq 'ARRAY'){
			foreach (@{$p->{author}}){
				$query .= " AND author exact ". $_;
			}
		}
		elsif($p->{author} and ref $p->{author} ne 'ARRAY'){
			$query .= " AND author exact ". $p->{author};
		}

		if($p->{editor} and ref $p->{editor} eq 'ARRAY'){
			foreach (@{$p->{editor}}){
				$query .= " AND editor exact ". $_;
			}
		}
		elsif($p->{editor} and ref $p->{editor} ne 'ARRAY'){
			$query .= " AND editor exact ". $p->{editor};
		}

		if($p->{person} and ref $p->{person} eq 'ARRAY'){
			foreach (@{$p->{person}}){
				$query .= " AND person exact ". $_;
			}
		}
		elsif($p->{person} and ref $p->{person} ne 'ARRAY'){
			$query .= " AND person exact ". $p->{person};
		}

		$query .= " AND qualitycontrolled=". $p->{qualitycontrolled} if $p->{qualitycontrolled};
		$query .= " AND popularscience=". $p->{popularscience} if $p->{popularscience};
		$query .= " AND nonlu=". $p->{nonunibi} if $p->{nonunibi};
		$query .= " AND fulltext=". $p->{fulltext} if $p->{fulltext};
		$query .= " AND basic=\"" . $p->{ftext} . "\"" if $p->{ftext};

		if($p->{publicationtype} and ref $p->{publicationtype} eq 'ARRAY'){
			my $tmpquery = "";
			foreach (@{$p->{publicationtype}}){
				$tmpquery .= "documenttype=" . $_ . " OR ";
			}
			$tmpquery =~ s/ OR $//g;
			$query .= " AND (" . $tmpquery . ")";
		}
		elsif ($p->{publicationtype} and ref $p->{publicationtype} ne 'ARRAY'){
			$query .= " AND documenttype=". $p->{publicationtype};
		}

		if($p->{publishingyear} and ref $p->{publishingyear} eq 'ARRAY'){
			my $tmpquery = "";
			foreach (@{$p->{publishingyear}}){
				$tmpquery .= "publishingyear=" . $_ . " OR ";
			}
			$tmpquery =~ s/ OR $//g;
			$query .= " AND (" . $tmpquery . ")";
		}
		elsif ($p->{publishingyear} and ref $p->{publishingyear} ne 'ARRAY'){
			$query .= " AND publishingyear=". $p->{publishingyear};
		}
		return $query;
	}

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

sub uri_for_file {
    my ($self, $pub, $file) = @_;
    my $ext = $self->file_extension($file->{fileName});
    $self->host . "/download/$pub->{_id}/$file->{fileOId}$ext";
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
