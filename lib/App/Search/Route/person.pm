package App::Search::Route::person;

=head1 NAME

App::Search::Route::person - handles routes for person sites

=cut
use Catmandu::Sane;
use Dancer qw/:syntax/;
use App::Helper;

=head2 GET /person

Search API for person data.

=cut
get qr{/person/*} => sub {
	my $tmpl = 'websites/index_publication.tt';
	my $p = h->extract_params();
	(params->{text} =~ /^".*"$/) ? (push @{$p->{q}}, params->{text}) : (push @{$p->{q}}, '"'.params->{text}.'"') if params->{text};

    $p->{start} = params->{start} if params->{start};
	$p->{limit} = params->{limit} || h->config->{default_page_size};

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

	$hits->{bag} = "person";
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

	push @{$p->{q}}, ("person=$id", "status=public");

	if($modus and $modus eq "data"){
		push @{$p->{q}}, "(type=researchData OR type=dara)";
	}
	else{
		push @{$p->{q}}, ("type<>researchData", "type<>dara");
	}

	my $sort_style = h->get_sort_style( $p->{sort} || '', $p->{style} || '', $id);
	$p->{sort} = $sort_style->{sort};
	$p->{facets} = h->default_facets();
	$p->{limit} = h->config->{maximum_page_size};

	my $hits = h->search_publication($p);

	# search for research hits (only to see if present and to display tab)
	my $researchhits;
	@{$p->{q}} = @orig_q;
	push @{$p->{q}}, ("(type=researchData OR type=dara)", "person=$id", "status=public");
	$p->{limit} = 1;

	$hits->{researchhits} = h->search_publication($p);

	$p->{limit} = h->config->{maximum_page_size};
	$hits->{style} = $sort_style->{style};
	$hits->{sort} = $p->{sort};
	$hits->{id} = $id;
	$hits->{modus} = $modus || "user";

	my $marked = session 'marked';
    $marked ||= [];
    $hits->{marked} = @$marked;

	if ($p->{fmt} ne 'html') {
		h->export_publication($hits, $p->{fmt});
	} else {
		template "home.tt", $hits;
	}
};

=head2 GET /person/alias

Find a person's ID via alias.
Forwards to /person/:ID

=cut
get qr{/person/(\w+)/*} => sub {
	my ($alias) = splat;

	my $hits = h->search_researcher({q => ["alias=$alias"]});
	if(!$hits->{total}){
		status '404';
		template 'websites/404', { path => request->path };
	}
	else {
		my $person = $hits->first;
		forward "/person/$person->{_id}";
	}
};

1;
