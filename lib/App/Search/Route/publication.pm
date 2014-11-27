package App::Search::Route::publication;

=head1 NAME

  App::Search::Route::publication - handling public record routes.

=cut

use Catmandu::Sane;
use Dancer qw/:syntax/;
use App::Helper;
# what for?
=head2 GET /{data|publication}/:id/:style

  Splash page style param '/publication/:id/:style' or '/data/:id/:style'

=cut
get qr{/(data|publication)/(\d{1,})/(\w{1,})/*} => sub {
	my ($bag, $id, $style) = splat;

	my $p = {
		q => "id=$id",
		style => $style,
		limit => 1,
		tmpl => "frontdoor/record",
		fmt => params->{fmt} || '',
	};
	$p->{'bag'} = "researchData" if $bag eq "data";
	my $hits = h->search_publication($p);
};

=head2 GET /{data|publication}/:id

  Splash page of a given record.

=cut
get qr{/(data|publication)/(\d{1,})/*} => sub {
	my ($bag, $id) = splat;
	my $p = h->extract_params();
	push @{$p->{q}}, "id=$id";

	my $hits = h->search_publication($p);
	$hits->{bag} = "researchData" if $bag eq "data";
	template "frontdoor/record", $hits->{hits}->[0];
};

# /data/doi/:doi
# get qr{/data/doi/(.*?)/*} => sub {
# 	my ($doi) = splat;
#
# 	my $p = h->extract_params();
# 	$p->{'bag'} = 'researchData';
# 	$p->{'q'} = "doi=$doi";
# 	#handle_request(\%p);
# };

# api for data publication lists
get qr{/data/*} => sub {
	my $p = h->extract_params();

	my $hits = h->search_publication($p);
	$hits->{bag} = 'researchData';
	template "websites/index_publication", $hits;
};

# api for publication lists
get qr{/publication/*} => sub {
	my $p = h->extract_params();
	my $hits = h->search_publication($p);
	$hits->{bag} = 'publication';
	template "websites/index_publication", $hits;
};

1;
