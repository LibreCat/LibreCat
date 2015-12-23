package App::Search::Route::publication;

=head1 NAME

App::Search::Route::publication - handling public record routes.

=cut

use Catmandu::Sane;
use Dancer qw/:syntax/;
use App::Helper;

=head2 GET /{data|publication}/:id

Splash page for :id.

=cut
get qr{/(data|publication)/(\d{1,})/*(\w{1,})*/*} => sub {
	my ($bag, $id, $style) = splat;
	my $p = h->extract_params();
	my $altid;
	push @{$p->{q}}, ("status=public","id=$id");
	push @{$p->{q}}, "type=researchData" if $bag eq 'data';

	my $hits = h->search_publication($p);

	if(!$hits->{total}){
		$p->{q} = [];
		push @{$p->{q}}, ("status=public", "altid=$id");
		push @{$p->{q}}, "type=researchData" if $bag eq 'data';
		$hits = h->search_publication($p);
		$altid = 1 if $hits->{total};
	}

	$hits->{bag} = $bag;

	my $marked = session 'marked';
    $marked ||= [];
    $hits->{hits}->[0]->{marked} = @$marked;
    $hits->{hits}->[0]->{style} = $style if $style;

	if ($p->{fmt} ne 'html') {
		h->export_publication($hits, $p->{fmt});
	} else {
		return redirect "$bag/$hits->{hits}->[0]->{_id}", 301 if $altid;
		$hits->{hits}->[0]->{bag} = $bag;
		$hits->{total} ? status 200 : status 404;
		template "frontdoor/record", $hits->{hits}->[0];
	}
};

=head2 GET /{data|publication}

Search API to (data) publications.

=cut
get qr{/(data|publication)/*} => sub {

	my ($bag) = splat;
	my $p = h->extract_params();
	$p->{facets} = h->default_facets();
	my $sort_style = h->get_sort_style( $p->{sort} || '', $p->{style} || '');
    $p->{sort} = $sort_style->{sort};

	($bag eq 'data') ? push @{$p->{q}}, ("status=public","(type=researchData OR type=dara)")
		: push @{$p->{q}}, ("status=public","type<>researchData","type<>dara");

	my $hits = h->search_publication($p);

	$hits->{style} = $sort_style->{style};
    $hits->{sort} = $p->{sort};
    $hits->{user_settings} = $sort_style;
	$hits->{bag} = $bag;

	if ($p->{fmt} ne 'html') {
		h->export_publication($hits, $p->{fmt});
	} elsif ($p->{embed} or ($p->{ftyp} and $p->{ftyp} eq "iframe")) {
		my $lang = $p->{lang} || session->{lang} || h->config->{default_lang};
		$hits->{lang} = $lang;
		$hits->{embed} = 1;
		template "iframe", $hits;
	} else {
		my $template = "websites/index_publication";
		if($p->{ftyp} and $p->{ftyp} =~ /ajx|js|pln/){
			$template .= "_" . $p->{ftyp};
			$template .= "_num" if ($p->{enum} and $p->{enum} eq "1");
			$template .= "_numasc" if ($p->{enum} and $p->{enum} eq "2");
			header("Content-Type" => "text/plain") unless ($p->{ftyp} eq 'iframe' || $p->{ftyp} eq 'pln');
		}
		template $template, $hits;
	}

};

=head2 GET /{data|publication}/embed

Embed API to (data) publications

=cut

get qr{/(data|publication)/embed/*} => sub {
        my ($bag) = splat;

        my $p = params;
        $p->{embed} = 1;
        forward "/$bag", $p;
};


get qr{/embed/*} => sub {
	my $p = h->extract_params();
	my $portal = h->config->{portal}->{$p->{ttyp}} if $p->{ttyp};
	my $pq;

	if($portal){
		$pq = h->is_portal_default($p->{ttyp});
		$p = $pq->{full_query};
	}
	push @{$p->{q}}, ("status=public");
	$p->{facets} = h->default_facets();

	# override default facets
	$p->{facets}->{author}->{terms}->{size} = 100;
	$p->{facets}->{editor}->{terms}->{size} = 100;

	my $sort_style = h->get_sort_style( params->{sort} || $pq->{default_query}->{'sort'} || '', params->{style} || $pq->{default_query}->{style} || '');
    $p->{sort} = $sort_style->{sort};
    $p->{start} = params->{start};
	my $hits = h->search_publication($p);
	$hits->{bag} = "publication";
	$hits->{embed} = 1;
	$hits->{ttyp} = $p->{ttyp} if $p->{ttyp};
	$hits->{style} = $sort_style->{style};#$p->{style} ? $p->{style} : h->config->{default_style};
	my $lang = $p->{lang} || session->{lang} || h->config->{default_lang};
	$hits->{lang} = $lang;
	template "iframe", $hits;
};

1;
