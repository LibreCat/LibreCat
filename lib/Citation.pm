package Citation;

use Catmandu::Sane;
use Catmandu -load;
use Catmandu::Util qw(:array);
use Catmandu::Error;
use Moo;
use JSON;
use LWP::UserAgent;

Catmandu->load(':up');
my $conf = Catmandu->config->{citation};

has styles => (is => 'ro', default => sub { ['default'] });
has locale => (is => 'ro', default => sub {'en'});
has all => (is => 'ro');
has debug => (is => 'ro');

sub BUILD {
	my ($self) = @_;
	if ($self->all) {
		$self->styles = $conf->{csl}->{styles};
	}
}

sub _request {
	my ($self, $content) = @_;

	my $ua = LWP::UserAgent->new();
	my $res = $ua->post($conf->{csl}->{url}, Content => $content);

	return $res if $self->debug;

	my $json = JSON->new();
	return $res->{_rc} eq '200'
		? $json->decode($res->{_content})->	[0]->{citation} : '';
}

sub create {
	my ($self, $data) = @_;

	unless ($data->{title}) {
		Catmandu::BadVal->throw('Title field is missing');
	}

	my $cite;

	if ($conf->{engine} eq 'template') {
		return { default => export_to_string('Template', $data, { template => $conf->{template}->{template_path} }) };
	} else {
		my $csl_json = export_to_string('JSON', $data, { array => 1, fix => 'fixes/to_csl.fix' });
		foreach my $s (@{$self->{styles}}) {
			my $locale = ($s eq 'dgps') ? 'de' : $self->locale;
			$cite->{$s} = $self->_request(["locale => $locale", "style => $s", "format => 'html'", "input => $csl_json"]);

		}

		return $cite;
	}

}

1;
