package Citation;

use Catmandu::Sane;
use Catmandu qw(:load export_to_string);
use Catmandu::Util qw(:array);
use Catmandu::Error;
use JSON;
use LWP::UserAgent;
use Moo;

Catmandu->load(':up');
my $conf = Catmandu->config->{citation};

has style => (is => 'ro');
has styles => (is => 'ro', lazy => 1, builder => '_build_styles');
has locale => (is => 'ro', default => sub {'en'});
has all => (is => 'ro');
has debug => (is => 'ro');

sub _build_styles {
	my ($self) = @_;
	if ($self->all) {
		return $conf->{csl}->{styles};
	} elsif ($self->style) {
		return [$self->style];
	} else {
		return ['default'];
	}
}

sub _request {
	my ($self, $content) = @_;

	my $ua = LWP::UserAgent->new();
	my $res = $ua->post($conf->{csl}->{url}, Content => $content);

	return $res if $self->debug;

	my $json = JSON->new();
	if ($res->{_rc} eq '200') {
		my $obj = $json->decode($res->{_content});
		return $obj->[0]->{citation};
	} else {
		return '';
	}
}

sub create {
	my ($self, $data) = @_;

	unless ($data->{title}) {
		Catmandu::BadVal->throw('Title field is missing');
	}

	my $cite;

	if ($conf->{engine} eq 'template') {
		return { default => export_to_string($data, 'Template', { template => $conf->{template}->{template_path} }) };
	} else {
		my $csl_json = export_to_string($data, 'JSON', { array => 1, fix => 'fixes/to_csl.fix' });
		foreach my $s (@{$self->{styles}}) {
			my $locale = ($s eq 'dgps') ? 'de' : $self->locale;
			$cite->{$s} = $self->_request([locale => $locale, style => $s, format => 'html', input => $csl_json]);

		}

		return $cite;
	}

}

1;
