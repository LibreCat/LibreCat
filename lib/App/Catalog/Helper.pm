package App::Catalog::Helper::Helpers;
use lib qw(/srv/www/sbcat/lib /srv/www/sbcat/lib/default /srv/www/sbcat/lib/extension);

use Catmandu::Sane;
use Catmandu qw(:load export_to_string);
use Catmandu::Util qw(:is :array trim);
use Catmandu::Fix qw /expand/;
use Dancer qw(:syntax vars params request);
use Sys::Hostname::Long;
use Hash::Merge qw(merge);
use Template;
use Moo;
use POSIX qw(strftime);

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

sub now {
	 my $now = strftime($_[0]->config->{time_format}, gmtime(time));
	 return $now;
}

sub genereteURN {
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

sub getPerson {
	my $user;
	my $admin;
	if($_[1] and $_[1] =~ /\d{1,}/){
		$user = $_[0]->authority_user->get($_[1]);
		$admin = $_[0]->authority_admin->get($_[1]);

		my @fields = qw(full_name last_name first_name email department super_admin reviewer dataManager delegate);
		map {
			$user->{$_} = $admin->{$_};
		} @fields;
		$user;
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
	return "http://" . hostname_long;
}

sub shost {
	return "https://" . hostname_long;
}

sub search_publication {
	my ($self, $p) = @_;

	my $hits;
	my $q = $p->{q} ||= "";
	my $default_sort = "";
	foreach (@{config->{store}->{default_sort}}){
		$default_sort .= "$_->{field},,";
		$default_sort .= $_->{order} eq "asc" ? "1 " : "0 ";
	}
	$default_sort = substr($default_sort, 0, -1);

	my $sort = $p->{'sort'} ||= $default_sort;
	my $bag = $p->{'bag'} ||= "publicationItem";

	$hits = publication->search(
	    cql_query => $p->{q},
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

sub search_researcher {
	my ($self, $p) = @_;
	my $q = $p->{q} ||= "";
	#$q .= $q eq "" ? "publCount>0" : " AND publCount>0";

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

sub uri_for {
    my ($self, $path, $uri_params) = @_;
    $uri_params ||= {};
    $uri_params = {%{$self->embed_params}, %$uri_params};
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

package App::Catalog::Helper;

my $h = App::Catalog::Helper::Helpers->new;

use Catmandu::Sane;
use Dancer qw(:syntax hook);
use Dancer::Plugin;

register h => sub { $h };

hook before_template => sub {

    $_[0]->{h} = $h;

};

register_plugin;

1;
