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
	push @{$p->{q}}, "type<>researchData";
	push @{$p->{q}}, "type<>dara";
	my $sort_style = h->get_sort_style( $p->{sort} || '', $p->{style} || '', $id);
	$p->{sort} = $sort_style->{sort};
	$p->{facets} = h->default_facets();

	my $hits = h->search_publication($p);
	
	my $researchhits;
	@{$p->{q}} = @orig_q;
	push @{$p->{q}}, "person=$id";
	push @{$p->{q}}, "(type=researchData OR type=dara)";
	$researchhits = h->search_publication($p);
	
	$hits->{researchhits} = $researchhits;
	
	$hits->{style} = $sort_style->{style};
	$hits->{sort} = $p->{sort};
	$hits->{id} = $id;
	$hits->{modus} = $modus || "user";
	template "home.tt", $hits;
};

=head2 GET /person/alias

Find a person's ID via alias.
Forwards to /person/:ID

=cut
get qr{/person/(\w+)/*} => sub {
	my ($alias) = splat;

	my $person = h->authority_user->select({"alias", $alias})->first;
	forward "/person/$person->{_id}";
};

=head2 GET /person

=cut
get qr{/person/*} => sub {
    my $path = h->host . '/authorlist';
    redirect $path;
};

1;
