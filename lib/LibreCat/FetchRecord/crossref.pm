package LibreCat::FetchRecord::crossref;

use Catmandu::Util qw(:io :hash);
use LibreCat -self;
use LibreCat::App::Helper;
use URI::Escape;
use Moo;
use XML::Hash;
use Furl;

with 'LibreCat::FetchRecord';

has 'baseurl' =>
    (is => 'ro', default => sub {"https://www.crossref.org/openurl/?format=unixsd"});

sub fetch {
    my ($self, $id) = @_;

    # Clean up data
    $id =~ s{^\D+[:\/]}{};

    $self->log->debug("requesting $id from crossref");

    my $url = sprintf "%s&pid=%s&id=doi:%s", $self->baseurl, h->config->{admin_email}, $id;
    my $result;
    my $xml_converter; my $xml_hash; my $data;

    my $furl = Furl->new(
      agent => "Chrome 35.1",
      headers => ['Content-type' => 'application/xml'],
    );

    $result = $furl->get($url);

    my $xml = $result->content;
    $xml =~ s/crm-item/crm_item/g;
    $xml =~ s/jats:(abstract|sec)/$1/g;
    $xml =~ s/\<jats:\w+\>//g;
    $xml =~ s/\<\/jats:title\>/ - /g;
    $xml =~ s/\<\/jats:\w+\>//g;
    $xml =~ s/(xml|ai):(lang|program|license_ref)/$1_$2/g;
    $xml =~ s/\<sup\>/&lt;sup&gt;/g;
    $xml =~ s/\<\/sup\>/&lt;\/sup&gt;/g;

    $xml_converter = XML::Hash->new();
    $xml_hash = $xml_converter->fromXMLStringtoHash($xml);
    $data = $xml_hash->{crossref_result}->{query_result}->{body}->{query};

    if($data->{status} eq "resolved"){
      my $fixer = librecat->fixer('crossref_mapping.fix');

      $data = $fixer->fix($data);

      return [$data];
    }
    else {
      return [{agency => "unresolved"}];
    }
}

1;

__END__

=pod

=head1 NAME

LibreCat::FetchRecord::crossref - Create a LibreCat publication based on a DOI

=head1 SYNOPSIS

    use LibreCat::FetchRecord::crossref;

    my $pub = LibreCat::FetchRecord::crossref->new->fetch('doi:10.1002/0470841559.ch1');

=cut
