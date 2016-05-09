package LibreCat::Citation;

=head1 NAME

LibreCat::Citation - creates citations via a CSL engine or template

=head1 SYNOPSIS

    use LibreCat::Citation;

    my $data = {};
    my $styles = LibreCat::Citation->new(all => 1)->create($data);
    # or
    LibreCat::Citation->new(style => 'apa')->creat($data);

=head1 CONFIGURATION

    # catmandu.yml
    citation:
      engine: template
      template:
        template_path: views/citation.tt
      csl:
        url: ...

=cut

use Catmandu::Sane;
use Catmandu qw(:load export_to_string);
use Catmandu::Util qw(:array);
use Catmandu::Error;
use JSON::MaybeXS qw(decode_json);
use LWP::UserAgent;
use Moo;

Catmandu->load(':up');
my $conf = Catmandu->config->{citation};
my $cat = Catmandu->default_load_path;

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

    if ($res->{_rc} eq '200') {
        my $obj = decode_json($res->{_content});
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
        my $csl_json = export_to_string($data, 'JSON', { array => 1, fix => "$cat/fixes/to_csl.fix" });
        foreach my $s (@{$self->styles}) {
            my $locale = ($s eq 'dgps') ? 'de' : $self->locale;
            $cite->{$s} = $self->_request([locale => $locale, style => $s, format => 'html', input => $csl_json]);

        }

        return $cite;
    }

}

1;
