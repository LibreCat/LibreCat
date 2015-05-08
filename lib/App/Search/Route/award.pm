package App::Search::Route::award;

=head1 NAME

App::Search::Route::award - handling routes for award pages.

=cut

use Catmandu::Sane;
use Dancer qw/:syntax/;
use App::Helper;

=head2 GET /en/award/:id

Project splash page for :id.

=cut

# /en/award/ID/
get qr{/en/award/(AW\d+)/*} => sub {
	my $servername = request->uri_base;
	if ($servername =~ /pub2\.ub/ or $servername =~ /pub\.uni-bielefeld/){
		forward '/';
	}
	
	my ($id) = splat;
	my $returnhash = {id => $id, lang => "en"};
	$returnhash->{params} = params if params;
	forward '/award', $returnhash;
};

# /award/ID/
get qr{/award/(AW\d+)/*} => sub {
	my $servername = request->uri_base;
	if ($servername =~ /pub\.uni-bielefeld/){
		forward '/';
	}
	
	my ($id) = splat;
	my $params = params || "";
	
	forward '/award', {id => $id, params => $params};
	
};

# /en/award
get qr{/en/award/*} => sub {
	my $servername = request->uri_base;
	if ($servername =~ /pub\.uni-bielefeld/){
		forward '/';
	}
	
	forward '/award', {lang => "en"};
};


# /award (main function, handling everything)
get qr{/award/*} => sub {
	my $servername = request->uri_base;
	if ($servername =~ /pub\.uni-bielefeld/){
		forward '/';
	}
	
	my $store = h->award;#Catmandu::Store::MongoDB->new(database_name => 'PUBAwards');
	#my $awardBag = $store->bag('awards');
	#my $academyBag = $store->bag('academy');
		
	my $id = params->{id} if params->{id};
	my $lang = params->{lang} if params->{lang};
	my $mailform = params->{mailform} if params->{mailform};
	my $returnhash;
	my $tmpl;
	
	# Email Award suggestion
	if($mailform and $mailform eq "sent"){
		my $name = params->{name};
		my $email = params->{email};
		my $preis = params->{awardname};
		my $message = params->{ftext};
		my $path = params->{lasturl};
		
		my $receiver = ['pressestelle@uni-bielefeld.de','petra.kohorst@uni-bielefeld.de'];
		
		$returnhash = {lasturl => $path};
		$returnhash->{formname} = params->{name} if params->{name};
		$returnhash->{formemail} = params->{email} if params->{email};
		$returnhash->{formaward} = params->{awardname} if params->{awardname};
		$returnhash->{formmessage} = params->{ftext} if params->{ftext};
		
		if($email and $email =~ /\@.*?\./ and ($message or $preis)){
			foreach my $recipient (@$receiver){
				open(MAIL, "|/usr/lib/sendmail -ti");
				print MAIL "To: $recipient\n";
				print MAIL "From: $email\n";
				print MAIL "Subject: Wissenschaftspreise: neuer Vorschlag\n\n";
				print MAIL "Eingetragen von $name <$email>:\n\n";
				print MAIL "$preis\n" if $preis;
				print MAIL "$message\n" if $message;
				close (MAIL);
			}
			
			$tmpl = "award/emailsent";
			$tmpl .= "_$lang" if $lang;
			return template $tmpl, {lasturl => $path};
		}
		else{
			if($lang and $lang eq "en"){
				$returnhash->{returnmessage} = "Please enter your email address.<br />" if !$email;
				$returnhash->{returnmessage} .= "Please enter a correct email address.\n" if ($email and $email !~ /\@.*?\./);
				$returnhash->{emailerror} = "ERROR" if (!$email or $email !~ /\@.*?\./);
				$returnhash->{returnmessage} .= "Please enter the name of the award in the field 'award name' or 'message'.\n" if (!$message and !$preis);
				$returnhash->{messageerror} = "ERROR" if (!$message and !$preis);
				$returnhash->{awarderror} = "ERROR" if (!$message and !$preis);
			}
			else {
				$returnhash->{returnmessage} = "Bitte geben Sie Ihre E-Mail Adresse ein.<br />" if !$email;
				$returnhash->{returnmessage} .= "Bitte geben Sie eine korrekte E-Mail Adresse ein.<br />" if ($email and $email !~ /\@.*?\./);
				$returnhash->{emailerror} = "ERROR" if (!$email or $email !~ /\@.*?\./);
				$returnhash->{returnmessage} .= "Bitte geben Sie unter 'Preisname' oder 'Nachricht' den Namen des Preises ein.<br />" if (!$message and !$preis);
				$returnhash->{messageerror} = "ERROR" if (!$message and !$preis);
				$returnhash->{awarderror} = "ERROR" if (!$message and !$preis);
			}
		}
	}
	
	# standard award page with (optional) search params
	if(!$id){
		
		my $cql = "";
		my $q = params->{q} if params->{q};
		my $year = params->{year} if params->{year};
		my $honoree = params->{honoree} if params->{honoree};
		my $department = params->{department} if params->{department};
		my $einrichtung = params->{einrichtung} if params->{einrichtung};
		
		if($q){
			$cql .= "\"$q\" AND ";
		}
		if($year and $year =~ /(\d{4}) - (\d{4})/){
			$cql .= "year>=$1 AND year<=$2 AND ";
		}
		else {
			$cql .= "year=\"$year\" AND " if $year;
		}
		$cql .= "honoree=\"$honoree\" AND " if $honoree;
		$cql .= "department=$department AND " if $department;
		$cql .= "einrichtung=$einrichtung AND " if $einrichtung;
		$cql .= "rectype=record";
		
		#$cql =~ s/ AND $//g;
		my $hits;
		
		my $preishits = h->award->search(
		    cql_query => $cql,
		    limit => h->config->{store}->{maximum_page_size},
		    facets => {
		    	year => {terms => {field => 'year', size => 100, order => 'reverse_term'}},
		    	department => {terms => {field => 'department.name.exact', size => 100, order => 'term'}},
		    	einrichtung => {terms => {field => 'einrichtung.name.exact', size => 100, order => 'term'}},
		    	person => {terms => {field => 'honoree.name.fullName.exact', size => 100, order => 'term'}},
		    },
		    sru_sortkeys => "year,,0",
		);
		
		$preishits->{facets}->{year} = group_year_facet($preishits->{facets}->{year}) if $preishits and $preishits->{facets}->{year};
		
		foreach my $hit (@{$preishits->{hits}}){
			#my $id = "";
			my $honoree;
			$honoree->{full_name} = $hit->{honoree}->[0]->{full_name};
			$honoree->{first_name} = $hit->{honoree}->[0]->{first_name};
			$honoree->{last_name} = $hit->{honoree}->[0]->{last_name};
			$honoree->{title} = $hit->{honoree}->[0]->{title};
			$honoree->{former_member} = $hit->{former_member} ||= "";
			$honoree->{id} = $hit->{honoree}->[0]->{id} ||= "";
			$honoree->{preis} = $hit->{_id};
			
			#$id = $hit->{academyId} if $hit->{academyId};
			#$id = $hit->{awardId} if $hit->{awardId};
			my $awardemy = $store->get($hit->{award_id});
			#$awardemy = $academyBag->get($hit->{academyId}) if $hit->{academyId};
			my $name = $awardemy->{title};
			
			push @{$hits->{lists}->{$hit->{award_id}}}, $honoree;
			
			my $displayname = "";
			$displayname = $honoree->{title}." " if $honoree->{title};
			if ($honoree->{first_name} && $honoree->{last_name}){
				$displayname .= $honoree->{first_name}. " " . $honoree->{last_name};
			}
			else {
				$displayname .= $honoree->{full_name};
			}
			
			push @{$hits->{lists}->{person}->{"$honoree->{full_name}"}}, {personNumber => $honoree->{id}, 
    		                                             name => $displayname,
    	                                                 awardId => $id,
    	                                                 };

    	    $hits->{lists}->{awardemy}->{$id} = $name;
    	    $hits->{lists}->{auszeichnungen}->{$hit->{award_id}} = $name if ($hit->{award_id} and $awardemy->{rec_type} eq "auszeichnung");
    	    $hits->{lists}->{awards}->{$hit->{award_id}} = $name if ($hit->{award_id} and $awardemy->{rec_type} eq "preis");
    	    $hits->{lists}->{academys}->{$hit->{award_id}} = $name if ($hit->{award_id} and $awardemy->{rec_type} eq "akademie");
		}
		
		$hits->{lists}->{total} = keys %{$hits->{lists}->{awardemy}} || 0;
		$hits->{lists}->{auszeichnungentotal} = keys %{$hits->{lists}->{auszeichnungen}} || 0;
		$hits->{lists}->{awardstotal} = keys %{$hits->{lists}->{awards}} || 0;
		$hits->{lists}->{academystotal} = keys %{$hits->{lists}->{academys}} || 0;
		
		$hits->{facets} = $preishits->{facets};
		$hits->{lists}->{persontotal} = keys %{$hits->{lists}->{person}};
		
		$hits->{formreturn} = $returnhash if $returnhash;
		
		$tmpl = "award/main";
		#$tmpl .= "_$lang" if $lang;
		$hits->{lang} = "en" if $lang;
		
		$hits->{dumper} = $preishits;
		template $tmpl, $hits;
	}
	
	# Award details page
	else {
		
		my $hits;
		$hits->{hits}->[0] = $store->get($id);
		$id = uc $id;
		
		if($hits->{hits}->[0]->{rec_type} ne "record"){
			
			$hits->{hits}->[0]->{people} = h->award->search(
			    cql_query => "awardid exact $id",
			    limit => params->{limit} ||= h->config->{store}->{default_searchpage_size},
			    start => params->{start} ||= 0,
			    sru_sortkeys => "year,,0",
			);
			
			$tmpl = "award/awardRecord";
			#$tmpl .= "_$lang" if $lang;
			$hits->{hits}->[0]->{lang} = "en" if $lang;
			
			$hits->{hits}->[0]->{id} = $id;
			return template $tmpl, $hits->{hits}->[0];
		}
		elsif($hits->{hits}->[0]->{rec_type} eq "record"){
			$hits = h->award->search(
			    cql_query => "id=$id",
			    limit => params->{limit} ||= h->config->{store}->{default_searchpage_size},
			    start => params->{start} ||= 0,
			);
			
			my $name = $hits->{hits}->[0]->{honoree}->[0]->{full_name};
			
			my $otherHits = h->award->search(
		        cql_query => "honoree exact \"$name\"",
		        limit => h->config->{store}->{default_searchpage_size},
		        start => 0,
		        sru_sortkeys => "year,,0",
		    );
		    
		    $hits->{hits}->[0]->{otheraward} = $otherHits if $otherHits->{total} != 0;
		}
		
		$tmpl = "award/preisRecord";
		#$tmpl .= "_$lang" if $lang;
		$hits->{hits}->[0]->{lang} = "en" if $lang;
		
		template $tmpl, $hits->{hits}->[0];
	}
    	
};

post '/en/awardemail' => sub {
	my $name = params->{name};
	my $email = params->{email};
	my $preis = params->{awardname};
	my $message = params->{ftext};
	my $path = params->{lasturl};
	
	my $receiver = ['pressestelle@uni-bielefeld.de','petra.kohorst@uni-bielefeld.de'];
	my $returnmessage = "";
	
	if($email and $message){
		foreach my $recipient (@$receiver){
			open(MAIL, "|/usr/lib/sendmail -ti");
			print MAIL "To: $recipient\n";
			print MAIL "From: $email\n";
			print MAIL "Subject: Wissenschaftspreise: neuer Vorschlag\n\n";
			print MAIL "Eingetragen von $name <$email>:\n\n";
			print MAIL "$preis\n" if $preis;
			print MAIL "$message\n" if $message;
			close (MAIL);
		}
		
	}
	elsif(!$email) {
		$returnmessage = "Please enter your email address.";
	}
	
	template "award/emailsent", {lasturl => $path};
};

############################

sub group_year_facet(){
	my $years = shift;
	my $groups;
	my ($sec,$min,$hour,$day,$mon,$year) = localtime(time); my $now = sprintf("%04d", 1900+$year);
	foreach my $term (@{$years->{terms}}){
		# the first if can be removed as soon as the import routine has been optimized to reduce several years to the first one
		my $termterm = $groups->{$term->{term}} ? int($groups->{$term->{term}}) : 0;
		my $termcount = $term->{count} ? int($term->{count}) : 0;
		if($term->{term} =~ /(\d{4})-\d{4}/){
			my $tempyear = $1;
			if($tempyear =~ /(\d{3})[0-4]$/){
				$term->{term} = int($1."4") > $now ? $1."0 - ".$now : $1."0 - ".$1."4";
				$groups->{$term->{term}} =  $termterm + $termcount;
			}
			elsif($tempyear =~ /(\d{3})[5-9]$/){
				$term->{term} = int($1."9") > $now ? $1."5 - ".$now : $1."5 - ".$1."9";
				$groups->{$term->{term}} = $termterm + $termcount;
			}
		}
		elsif($term->{term} =~ /(\d{3})[0-4]$/){
			$term->{term} = int($1."4") > $now ? $1."0 - ".$now : $1."0 - ".$1."4";
			$groups->{$term->{term}} = $termterm + $termcount;
		}
		elsif($term->{term} =~ /(\d{3})[5-9]$/){
			$term->{term} = int($1."9") > $now ? $1."5 - ".$now : $1."5 - ".$1."9";
			$groups->{$term->{term}} = $termterm + $termcount;
		}
	}
	$years->{terms} = [];
	
	foreach my $key (sort {$b cmp $a} keys %$groups){
		push @{$years->{terms}}, {term => $key, count => $groups->{$key}};
	}
	return $years;
}

1;