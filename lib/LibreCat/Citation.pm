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

    engine: {csl|none}

    csl:
      url: 'http://localhost:8085'
      default_style: chicago
      styles:
        - modern-language-association
        - chicago
        - ...

=cut

use Catmandu::Sane;
use LibreCat::App::Helper;
use Catmandu qw(export_to_string);
use Catmandu::Util qw(:array);
use Clone qw(clone);
use LWP::UserAgent;
use Encode qw(encode_utf8);
use URI ();
use Moo;
use namespace::clean;

with 'Catmandu::Logger';

has style  => (is => 'ro');
has locale => (is => 'ro', default => sub {'en'});
has all    => (is => 'ro');

has conf      => (is => 'lazy');
has styles    => (is => 'lazy');
has csl_fixer => (is => 'lazy');

sub _build_conf {
    LibreCat::App::Helper::Helpers->new->config->{citation};
}

sub _build_styles {
    my ($self) = @_;
    if ($self->all) {
        return [keys %{$self->conf->{csl}->{styles}}];
    }
    elsif ($self->style) {
        return [$self->style];
    }
    else {
        return [$self->conf->{csl}->{default_style}];
    }
}

sub _build_csl_fixer {
    Catmandu->fixer('fixes/to_csl.fix');
}

sub _request {
    my ($self, $data) = @_;

    my $ua  = LWP::UserAgent->new();

    my $uri = URI->new($self->conf->{csl}->{url});
    $uri->query_form({
                    responseformat => 'html',
                    linkwrap => 1,
                    style => $data->{style}
          });

    my $res = $ua->post(
                    $uri->as_string(),
                    Content => encode_utf8($data->{content})
            );

    if ($res->{_rc} eq '200') {
        $self->log->debug("200 OK for " . $uri->as_string());

        my $content = $res->{_content};
        $content =~ s/<div class="csl-left-margin">.*?<\/div>//g;
        $content =~ s/<div.*?>|<\/div>//g;
        # More regexes for backwards compatibility
        $content =~ s/^\s+//g;
        $content =~ s/\s+$//g;
        $content =~ s/__LINE_BREAK__/\<br \/\>/g;
        utf8::decode($content);
        return $content;
    }
    else {
        $self->log->error("Error: " . $res->{_rc});
        return undef;
    }
}

sub create {
    my ($self, $data) = @_;

    my $cite = {};

    my $engine = $self->conf->{engine} // 'none';

    if (0) {}
    elsif ($engine eq 'csl') {
        my $d         = clone $data;
        my $csl_fixer = $self->csl_fixer;
        my $csl_json  = export_to_string($d, 'JSON',{
                                line_delimited => 1, fix => $csl_fixer
                        });

        my $found = 0;
        foreach my $s (@{$self->styles}) {
            my $locale  = ($s eq 'dgps') ? 'de' : $self->locale;
            my $citation = $self->_request({
                        locale  => $locale,
                        style   => $self->conf->{csl}->{styles}->{$s},
                        content => $csl_json,
                    });

            if ($citation) {
                $cite->{$s} = $citation;
                $found = 1;
            }
        }

        return $found ? $cite : undef;
    }
    else {
        return undef;
    }
}

1;
