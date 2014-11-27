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
	my $p;
	$p->{q} = "";
	if(params->{q}){
    	$p->{q} = params->{q};
    }
	elsif (params->{ftext}) {
		my @textbits = split " ", params->{ftext};
		foreach (@textbits){
			$p->{q} .= " AND " . $_;
		}
		$p->{q} =~ s/^ AND //g;
        #$p->{q} = params->{ftext};
    }

    $p->{start} = params->{start} if params->{start};
	$p->{limit} = params->{limit} if params->{limit};

	if(params->{former}){
		$p->{q} .= " AND former=" if $p->{q} ne "";
		$p->{q} = "former=" if $p->{q} eq "";
		$p->{q} .= params->{former} eq "yes" ? "1" : "0";
	}
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
get qr{/person/(^\d{1,})/*} => sub {
	my ($id) = splat;
	my $p = h->extract_params();
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
get qr{/person/$} => sub {
    my $path = h->host . '/authorlist';
    redirect $path;
};

get qr{/person$} => sub {
	my $path = h->host . '/authorlist';
	redirect $path;
};
