package App::Search::Route::person;

=head1 NAME

App::Search::Route::person - handles routes for person sites

=cut
use Catmandu::Sane;
use Dancer qw/:syntax/;
use App::Helper;

# /authorlist
get '/authorlist' => sub {
	my $tmpl = 'websites/index_publication.tt';
	my $p = h->extract_params();
	(params->{text} =~ /^".*"$/) ? (push @{$p->{q}}, params->{text}) : (push @{$p->{q}}, '"'.params->{text}.'"') if params->{text};

    $p->{start} = params->{start} if params->{start};
	$p->{limit} = params->{limit} if params->{limit};

	if(params->{former}){
		my $former;
		(params->{former} eq "yes") ? ($former = "former=1") : ($former = "former=0");
		push @{$p->{q}}, $former;
	}

	push @{$p->{q}}, "publcount>0";

	my $cqlsort;
	if(params->{sorting} and params->{sorting} =~ /(\w{1,})\.(\w{1,})/){
		$cqlsort = $1 . ",,";
		$cqlsort .= $2 eq "asc" ? "1" : "0";
	}
	$p->{sorting} = $cqlsort;

	#to tell h->search_researcher to return people with one or more publications only
	$p->{researcher_list} = 1;

	my $hits = h->search_researcher($p);

	$hits->{bag} = "authorlist";
	$hits->{former} = params->{former} if params->{former};

	template $tmpl, $hits;
};

=head2 GET /person/:id

Returns a person's profile page, including publications,
research data and author IDs.

=cut
get qr{/person/(\d{1,})/*(\w+)*/*} => sub {
	my ($id, $modus) = splat;
	my $p = h->extract_params();

	my @orig_q = @{$p->{q}};

	push @{$p->{q}}, "person=$id";
	push @{$p->{q}}, "status=public";

	if($modus and $modus eq "data"){
		push @{$p->{q}}, "(type=researchData OR type=dara)";
	}
	else{
		push @{$p->{q}}, "type<>researchData";
		push @{$p->{q}}, "type<>dara";
	}
	my $sort_style = h->get_sort_style( $p->{sort} || '', $p->{style} || '', $id);
	$p->{sort} = $sort_style->{sort};
	$p->{facets} = h->default_facets();
	$p->{limit} = h->config->{store}->{maximum_page_size};

	my $hits = h->search_publication($p);

	# search for research hits (only to see if present and to display tab)
	my $researchhits;
	@{$p->{q}} = @orig_q;
	push @{$p->{q}}, "(type=researchData OR type=dara)";
	push @{$p->{q}}, "person=$id";
	$p->{limit} = 1;
	$researchhits = h->search_publication($p);
	$hits->{researchhits} = $researchhits;

	$p->{limit} = h->config->{store}->{maximum_page_size};
	$hits->{style} = $sort_style->{style};
	$hits->{sort} = $p->{sort};
	$hits->{id} = $id;
	$hits->{modus} = $modus || "user";

	my $marked = session 'marked';
    $marked ||= [];
    $hits->{marked} = @$marked;

	template "home.tt", $hits;
};

=head2 GET /person/alias

Find a person's ID via alias.
Forwards to /person/:ID

=cut
get qr{/person/(\w+)/*} => sub {
	my ($alias) = splat;

	my $person = h->search_researcher({q => {alias => $alias}})->first;
	if(!$person){
		status '404';
		template 'websites/404', { path => request->path };
	}
	else {
		forward "/person/$person->{_id}";
	}
};

=head2 GET /person

=cut
get qr{/person/*} => sub {
    my $path = h->host . '/authorlist';
    redirect $path;
};

1;
