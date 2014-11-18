package App::Search::Route::publication;

=head1 NAME

  App::Search::Route::publication - handling public record routes.

=cut

use Catmandu::Sane;
use Dancer qw/:syntax/;
# use *search module*
# what for?
=head2 GET /{data|publication}/:id/:style

  Splash page style param '/publication/:id/:style' or '/data/:id/:style'

=cut
get qr{/(data|publication)/(\d{1,})/(\w{1,})/*} => sub {
	my ($bag, $id, $style) = splat;
	my $p = {q => "id=$id", style => $style, limit => 1, tmpl => "frontdoor/record"};
	$p->{fmt} = params->{fmt} if params->{fmt};
	$p->{'bag'} = "researchData" if $bag eq "data";
	#handle_request($p);
};

=head2 GET /{data|publication}/:id

  Splash page of a given record.

=cut
get qr{/(data|publication)/(\d{1,})/*} => sub {
	my ($bag, $id) = splat;
	my $p = {q => "id=$id", limit => 1, style => $fd_style, tmpl => "frontdoor/record"};
	$p->{fmt} = params->{fmt} if params->{fmt};
	$p->{'bag'} = "researchData" if $bag eq "data";
	#handle_request($p);
};

# /data/doi/:doi
get qr{/data/doi/(.*?)/*} => sub {
	my ($doi) = splat;
	my $p = params;
	$p->{'bag'} = 'researchData';
	$p->{'q'} = "doi=$doi";
	#handle_request(\%p);
};

# api for data publication lists
get qr{/data/*} => sub {
	my $p = params;
	$p->{'bag'} = 'researchData';
	#handle_request(\%p);
};

# api for publication lists
get qr{/publication/*} => sub {
	my $p = params;
	#handle_request(\%p);
};

1;
