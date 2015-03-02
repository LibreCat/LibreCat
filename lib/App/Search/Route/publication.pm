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
get qr{/(data|publication)/(\d{1,})/*} => sub {
	my ($bag, $id) = splat;
	my $p = h->extract_params();
	push @{$p->{q}}, ("status=public","id=$id");

	my $hits = h->search_publication($p);
	$hits->{bag} = $bag;

	if ($p->{fmt} ne 'html') {
		h->export_publication($hits, $p->{fmt});
	} else {
		$hits->{hits}->[0]->{bag} = $bag;
		template "frontdoor/record", $hits->{hits}->[0];
	}
};

=head2 GET /{data|publication}

=cut
get qr{/(data|publication)/*} => sub {
	my ($bag) = splat;
	my $p = h->extract_params();
	$p->{facets} = h->default_facets();

	($bag eq 'data') ? push @{$p->{q}}, ("status=public","(type=researchData OR type=dara)")
		: push @{$p->{q}}, ("status=public","type<>researchData","type<>dara");

	my $hits = h->search_publication($p);
	$hits->{bag} = $bag;

	if ($p->{fmt} ne 'html') {
		h->export_publication($hits, $p->{fmt});
	} elsif ($p->{ttype}) {
		template "websites/index_publication_$p->{ttype}", $hits;
	} else {
		template "websites/index_publication", $hits;
	}
};

1;
