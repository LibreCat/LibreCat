package App::Search::Route::mark;

=head1 NAME

App::Search::Route::mark - handles mark and ordering of marked records.
This is stored in the session.

=cut

use Catmandu::Sane;
use Catmandu qw(:load store export_to_string);
use Catmandu::Util qw(:is :array);
use Dancer qw(:syntax);
use Catmandu::Util;
use List::Util;
use DateTime;
use App::Helper;

=head2 GET /marked

Returns list of marked records.

=cut
get '/marked' => sub {

    my $p = h->extract_params();
    my $fmt = $p->{fmt};
    my $explinks = $p->{explinks};
    my $marked = session 'marked';
    my ($hits, @tmp_hits);

    if($marked and ref $marked eq "ARRAY"){
        while ( my @chunks = splice(@$marked,0,100) ) {
            $p->{q} = ["(id=".join(' OR id=', @chunks). ")"];
            $p->{limit} = 100;
            $hits = h->search_publication($p);
            push @tmp_hits, @{$hits->{hits}};
        }
    	$hits->{explinks} = $explinks;
    	$hits->{style} = params->{style} || h->config->{store}->{default_style};
    }

    $hits->{hits} = \@tmp_hits;
    $hits->{total} = scalar @tmp_hits;

    if($fmt and $fmt ne 'html' and $hits->{total} ne "0"){
    	h->export_publication( $hits, $fmt );
    }
    else {
    	template 'websites/marked', $hits;
    }

};

=head2 POST /mark/:id

Mark the record with ID :id.

=cut
post '/mark/:id' => sub {

    my $id = param 'id';
    my $del = params->{'x-tunneled-method'};
    if($del){
    	my $marked = session 'marked';
    	if ($marked) {
			$marked = [ grep { $_ ne $id } @$marked ];
			session 'marked' => $marked;
		}
		content_type 'application/json';
		return to_json {
			ok => true,
			total => scalar @$marked,
		};
    }

    forward '/marked', {q => "id=$id"};

};

post '/marked' => sub {

	my $p = h->extract_params();
	my $del = params->{'x-tunneled-method'};
	my $tab = params->{'tab'};
	my $marked = [];
	$marked = session 'marked';
    	$p->{limit} = h->config->{store}->{maximum_page_size};
    	$p->{start} = 0;
	push @{$p->{q}}, "status exact public";

	if ($tab) {
		push @{$p->{q}}, "research_data=1";
	} else {
		push @{$p->{q}}, "research_data<>1";
	}

	if($del){
		if (session 'marked') {
			session 'marked' => [];
		}
		return to_json {
			ok => true,
			total => 0,
		};
	}

    my $hits = h->search_publication($p);

    if ($hits->{total} > $hits->{limit} && @$marked == 500) {
        return to_json {
            ok => true,
            message => "the marked list has a limit of 500 records, only the first 500 records will be added",
            total => scalar @$marked,
        };
    }
    elsif($hits->{total}){
    	foreach (@{$hits->{hits}}){
    		my $id = $_->{_id};
    		push @$marked, $id unless array_includes($marked, $id);
    	}

    	session 'marked' => $marked;
    }

    content_type 'application/json';
    return to_json {
        ok => true,
        total => scalar @$marked,
    };

};

post '/reorder/:id/:newpos' => sub {

    forward '/reorder', {id => params->{id}, newpos => params->{newpos}};

};

post '/reorder' => sub {

    my $marked = session 'marked';

    $marked = [ grep { $_ ne params->{id} } @$marked ];

	my @rest = splice (@$marked,param->{newpos});
	push @$marked, params->{id};
	push @$marked, @rest;

	session 'marked' => $marked;

};

1;
