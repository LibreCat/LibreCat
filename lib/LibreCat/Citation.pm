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

    # config/citation.yml
    prefix:
      _citation:

    engine: {template|csl}
    template:
      template_path: views/citation.tt
    csl:
      url: 'http://localhost:8085'
      default_style: chicago
      styles:
        - modern-language-association
        - chicago
        - ...

=cut

use Catmandu::Sane;
use Catmandu qw(export_to_string);
use Catmandu::Util qw(:array);
use Catmandu::Error;
use LWP::UserAgent;
use Encode qw(encode_utf8);
use URI ();
use Moo;
use namespace::clean;

with 'Catmandu::Logger';

my $conf = Catmandu->config->{citation};
my $load_path = Catmandu->default_load_path;

has style => (is => 'ro');
has styles => (is => 'ro', lazy => 1, builder => '_build_styles');
has locale => (is => 'ro', default => sub {'en'});
has all    => (is => 'ro');
has debug  => (is => 'ro');

sub _build_styles {
    my ($self) = @_;
    if ($self->all) {
        return $conf->{csl}->{styles};
    }
    elsif ($self->style) {
        return [$self->style];
    }
    else {
        return [$conf->{csl}->{default_style}];
    }
}

sub _request {
    my ($self, $data) = @_;

    my $ua = LWP::UserAgent->new();
    my $uri = URI->new($conf->{csl}->{url});
    $uri->query_form({
        responseformat => 'html',
        linkwrap => 1,
        style => $data->{style},
    });
    my $res = $ua->post(
        $uri->as_string(),
        Content => encode_utf8($data->{content}),
    );

    return $res if $self->debug;

    if ($res->{_rc} eq '200') {
        $self->log->debug("200 OK for " . $uri->as_string());
        my $content = $res->{_content};
        $content =~ s/<div class="csl-left-margin">.*?<\/div>//g;
        $content =~ s/<div.*?>|<\/div>//g;
        utf8::decode($content);
        return $content;
    }
    else {
        $self->log->error("Error: " . $res->{_rc});
        return 0;
    };

}

sub create {
    my ($self, $data) = @_;

    unless ($data->{title}) {
        Catmandu::BadVal->throw('Title field is missing');
    }

    my $cite;

    if ($conf->{engine} eq 'template') {
        return {
            default => export_to_string(
                $data, 'Template',
                {template => $conf->{template}->{template_path}}
            )
        };
    }
    else {
        my $csl_json = export_to_string($data, 'JSON',
            {line_delimited => 1, fix => "$load_path/fixes/to_csl.fix"});
        foreach my $s (@{$self->styles}) {
            my $locale = ($s eq 'dgps') ? 'de' : $self->locale;
            $cite->{$s} = $self->_request({
                locale => $locale,
                style  => $s,
                content  => $csl_json,
                });

        }

        return $cite;
    }

}

1;
