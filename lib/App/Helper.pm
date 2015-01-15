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

	if($params->{fmt}){
		$p->{fmt} = $params->{fmt};
		#my $formats = $self->config->{exporter}->{publication};
		#$p->{fmt} = $formats->{$params->{fmt}} ? $params->{fmt} : $self->config->{store}->{default_fmt};
	}

	push @{$p->{q}}, $params->{text} if $params->{text};

	$p->{style} = $params->{style} if $params->{style};
	$p->{sort} = $self->string_array($params->{sort});

	$p;
}

sub get_sort_style {
	my ($self, $sort, $style, $id) = @_;
	my $user = $self->getPerson( Dancer::session->{personNumber} || $id );
	my $return;
	$sort = undef if ($sort eq "" or (ref $sort eq "ARRAY" and !$sort->[0]));
	$style = undef if $style eq "";
	# set default values - to be overriden by more important values
	my $return_style = $style || $user->{style} || $self->config->{store}->{default_style};
	my $return_sort;
	my $return_sort_backend;
	if($sort){
		$sort = [$sort] if ref $sort ne "ARRAY";
		foreach my $s (@{$sort}){
			push @$return_sort, $s;
			push @$return_sort_backend, $s;
		}
	}
	elsif($user->{'sort'}){
		foreach my $s (@{$user->{'sort'}}){
			push @$return_sort, $s;
			push @$return_sort_backend, $s;
		}
	}
	else{
		foreach my $s (@{$self->config->{store}->{default_sort}}){
			push @{$return_sort}, $s;
		}
		foreach my $s (@{$self->config->{store}->{default_sort_backend}}){
			push @{$return_sort_backend}, $s;
		}
	}

	#$return_sort = [$return_sort] if(ref $return_sort ne "ARRAY");
#	foreach my $s (@{$return_sort}){
#		if($s =~ /(\w{1,})\.(\w{1,})/){
#			my $sorting = "$1,,";
#			$sorting .= $2 eq "asc" ? "1 " : "0 ";
#			$return->{'sort'} .= $sorting;
#		}
#		else{
#			$return->{'sort'} .= "$s,,0 ";
#		}
#	}
	#$return_sort_backend = [$return_sort_backend] if(ref $return_sort_backend ne "ARRAY");
#	foreach my $s (@{$return_sort_backend}){
#		if($s =~ /(\w{1,})\.(\w{1,})/){
#			my $sorting = "$1,,";
#			$sorting .= $2 eq "asc" ? "1 " : "0 ";
#			$return->{sort_backend} .= $sorting;
#		}
#		else{
#			$return->{sort_backend} .= "$s,,0 ";
#		}
#	}
	$return->{'sort'} = $return_sort;
	$return->{sort_backend} = $return_sort_backend;
	$return->{user_sort} = $user->{'sort'} if $user->{'sort'};
	$return->{user_style} = $user->{style} if $user->{style};

	# see if style param is set
	if(array_includes($self->config->{lists}->{styles},$return_style)){
		$return->{style} = $return_style;
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
	
	my $user_eq_backend = "";
	my $backend_eq_default = "";
	$user_eq_backend = @{$return->{user_sort}} ~~ @{$return->{sort_backend}} if $return->{user_sort};
	$backend_eq_default = @{$return->{sort_backend}} ~~ @{$self->config->{store}->{default_sort_backend}};
	
	if($user_eq_backend ne "" or (!$return->{user_sort} and $backend_eq_default ne "")){
		$return->{sort_up_to_date} = 1;
	}
	if(($return->{user_style} and $return->{style} eq $return->{user_style}) or (!$return->{user_style} and $return->{style} eq $self->config->{store}->{default_style})){
		$return->{style_up_to_date} = 1;
	}

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

sub get_list {
	my $list = $_[1];
	my $map;
	$map = config->{lists}{$list};
	$map;
}

sub get_statistics {
	my ($self) = @_;
	my $stats;
	my $hits = $self->search_publication({q => ["status=public"]});
	my $reshits = $self->search_publication({q => ["status=public","(type=researchData OR type=dara)"]});
	my $oahits = $self->search_publication({q => ["status=public","fulltext=1"]});
	my $disshits = $self->search_publication({q => ["status=public","type=bi*"]});
	my $people = $self->search_researcher();

	$stats->{publications} = $hits->{total} if $hits and $hits->{total};
	$stats->{researchdata} = $reshits->{total} if $reshits and $reshits->{total};
	$stats->{oahits} = $oahits->{total} if $oahits and $oahits->{total};
	$stats->{theseshits} = $disshits->{total} if $disshits and $disshits->{total};
	$stats->{pubpeople} = $people->{total} if $people and $people->{total};

	return $stats;
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
		quality_controlled => { terms => { field => 'quality_controlled', size => 1 } },
		popular_science => { terms => { field => 'popular_science', size => 1 } },
		extern => { terms => { field => 'extern', size => 1 } },
		status => { terms => { field => 'status', size => 8 } },
		year => { terms => { field => 'year'} },
		type => { terms => { field => 'type', size => 25 } },
	};
}

sub sort_to_sru {
	my ($self, $sort) = @_;
	my $cql_sort;
	foreach my $s (@$sort){
		if($s =~ /(\w{1,})\.(asc|desc)/){
			$cql_sort .= "$1,,";
			$cql_sort .= $2 eq "asc" ? "1 " : "0 ";
		}
	}
	$cql_sort = trim($cql_sort);
	return $cql_sort;
}

sub display_doctypes {
	my $map = config->{forms}{publicationTypes};
	my $doctype;
	$doctype = $map->{lc $_[1]}->{label};
	$doctype = "biDissertation" if (lc $_[1] eq "bidissertation");
	$doctype = "Translation" if(lc $_[1] eq "translation");
	$doctype = "Case Study" if (lc $_[1] eq "casestudy");
	$doctype;
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
	$cql = join(' AND ', @{$p->{q}}) if $p->{q};

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

sub export_hits {
	my ($self, $hits) = @_;
	my $tmpl = $hits->{tmpl} ||= 'websites/index_publication.tt';
	my $params = $hits->{params};

	my $marked = Dancer::session 'marked';
    $marked ||= [];

	if ( !$params->{fmt} || $params->{fmt} eq 'html' ) {
		if ($params->{ftyp}) {
			$tmpl .= "_". $params->{ftyp};
			#header("Content-Type" => "text/plain") unless ($params->{ftyp} eq 'iframe' || $params->{ftyp} eq 'pln');
			$hits->{header} = "text/plain" unless ($params->{ftyp} eq 'iframe' || $params->{ftyp} eq "pln");
			$tmpl .= "_num" if ($params->{enum} and $params->{enum} eq "1");
			$tmpl .= "_numasc" if ($params->{enum} and $params->{enum} eq "2");
			$hits->{tmpl} = $tmpl;
			#template $tmpl, $hits;
		}

		if($params->{limit} == 1 && @{$hits->{hits}}[0]){
			@{$hits->{hits}}[0]->{style} = $params->{style} if $params->{style};
			@{$hits->{hits}}[0]->{marked} = @$marked;
			@{$hits->{hits}}[0]->{bag} = $hits->{bag};
			@{$hits->{hits}}[0]->{tmpl} = "frontdoor/record.tt";
			$hits = @{$hits->{hits}}[0];
			#template "frontdoor/record.tt", @{$hits->{hits}}[0];
		} else {
			#template $tmpl, $hits;
			$hits->{tmpl} = $tmpl;
		}
		return $hits;
	}
	elsif($params->{fmt} eq 'jsonintern'){
		my $jsonstring = "[";

#		if($params->{bag} and $researchhits->{total}){
#			foreach (@{$researchhits->{hits}}){
#				my $mainTitle = $_->{mainTitle};
#				$mainTitle =~ s/"/\\"/g;
#				my $citation = $_->{citation}->{$style};
#				$citation =~ s/"/\\"/g;
#				$jsonstring .= "{oId:\"" . $_->{oId} . "\", title:\"" . $mainTitle . "\", citation:\"" . $citation . "\"},";
#			}
#		}
#		else{
			foreach (@{$hits->{hits}}){
				my $mainTitle = $_->{title};
				$mainTitle =~ s/"/\\"/g;
				my $citation = $params->{style} ? $_->{citation}->{$params->{style}} : $_->{citation}->{"frontShort"};
				$citation =~ s/"/\\"/g;
				$jsonstring .= "{oId:\"" . $_->{_id} . "\", title:\"" . $mainTitle . "\", citation:\"" . $citation . "\"},";
			}
#		}
		$jsonstring =~ s/,$//g;
		$jsonstring .= "]";
		$hits->{tmpl} = "json";
		$hits->{jsonstring} = $jsonstring;
		#return $jsonstring;
		return $hits;
	}
	else {
#		if($params->{bag} and $researchhits->{total}){
#			$researchhits->{explinks} = $explinks if $explinks;
#			$self->export_publication($researchhits, $fmt);
#		}
#		else {
			$hits->{explinks} = $params->{explinks} if $params->{explinks};
			$self->export_publication( $hits, $params->{fmt} );
#		}
	}

}

sub export_publication {
	my ($self, $hits, $fmt) = @_;

	if ($fmt eq 'csl_json') {
		$self->export_csl_json($hits);
	}

	if ( my $spec = config->{export}->{publication}->{$fmt} ) {
	   my $package = $spec->{package};
	   my $options = $spec->{options} || {};
	   if($hits->{style} and $hits->{style} ne "frontShort"){
			$options->{style} = $hits->{style};
	   }
	   else {
	      $options->{style} = "frontShortTitle";
	   }
	   $options->{explinks} = $hits->{explinks};
	   my $content_type = $spec->{content_type} || mime->for_name($fmt);
	   my $extension    = $spec->{extension} || $fmt;

	   my $export_obj;
	   my $rec;
	   my $meta;

	   if ($fmt eq 'json' || $fmt eq 'yaml') {
	   		$meta->{downloaded_from} = $self->host;
	   		$meta->{date_downloaded} = $self->current_time;
	   		$meta->{total_records} = $hits->total;
	   		foreach my $r (@{$hits->{hits}}) {
	   			push @{$export_obj->{records}}, {record => $r};
	   		}
	   		$export_obj->{meta} = $meta;
	   	} else {
	   		$export_obj = $hits->{hits};
	   	}

	   my $f = export_to_string( $export_obj, $package, $options );
	   ($fmt eq 'bibtex') && ($f =~ s/(\\"\w)\s/{$1}/g);
	   return Dancer::send_file (
   	      \$f,
	      content_type => $content_type,
	      filename     => "publications.$extension"
	   );
	}

}

sub export_csl_json{
	my ($self, $hits) = @_;

	my $spec = config->{export}->{publication}->{csl_json};
	my $out;
	$hits->each(sub {
		my $id = $_[0]->{_id};
		my $csl = Citation::id2citation($id,0,'csl_json');
		push @$out, $csl;
		});

	my $f = export_to_string($out, $spec->{package}, $spec->{options} || {});
	return Dancer::send_file (
   	    \$f,
	    content_type => $spec->{content_type},
	    filename     => "publications.$spec->{extension}"
	   );
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
	my $cql = "";
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
