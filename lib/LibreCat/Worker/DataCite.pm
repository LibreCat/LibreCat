package LibreCat::Worker::DataCite;

use Catmandu::Sane;
use Furl;
use HTTP::Headers;
use HTTP::Request;
# use Term::ReadKey;
# use URI;
# use URI::Escape;
use Encode qw(encode_utf8);
use Try::Tiny;
use Moo;
use namespace::clean;

with 'LibreCat::Worker';

has base_url => (is => 'lazy');
has user     => (is => 'ro', required => 1);
has password => (is => 'ro', required => 1);
has test_mode => (is => 'ro');

sub _build_base_url {
    my $self = shift;
    $self->test_mode ? return 'https://mds.test.datacite.org' : return 'https://mds.datacite.org';
}

sub work {
    my ($self, $opts) = @_;

    my $metadata = $self->metadata($opts->{doi}, $opts->{datacite_xml});
    my $mint = $self->mint($opts->{doi}, $opts->{landing_url});

    return {metadata => $metadata, mint => $mint};
}

sub mint {
    my ($self, $doi, $landing_url) = @_;

    return unless $doi && $landing_url;

    $self->log->debug("Minting $doi to $landing_url.");

    my $uri = URI->new($self->base_url);
    $uri->path("doi");
    $uri->query_form(
        doi => $doi,
        url => $landing_url,
        testMode => $self->test_mode ? 'true' : 'false',
    );
    $self->_do_request('POST', $uri->as_string, 'text/plain;charset=UTF-8',);
}

sub metadata {
    my ($self, $doi, $datacite_xml) = @_;

    return unless $doi && $datacite_xml;

    $self->log->debug("Register metadata for $doi. XML: $datacite_xml.");

    my $uri = URI->new($self->base_url);
    $uri->path("doi");
    $uri->query_form(
        testMode => $self->test_mode ? 'true' : 'false',
    );
    $self->_do_request(
        'POST', $uri->as_string, $datacite_xml, 'application/xml;charset=UTF-8',
    );
}

sub _do_request {
    my ($self, $method, $url, $content, $content_type) = @_;

    my $headers = HTTP::Headers->new(
        Accept         => 'application/xml',
        'Content-Type' => $content_type,
    );

    my $req = HTTP::Request->new($method => $url, $headers,
        encode_utf8($content));

    $self->log->debug("Sending $method request to $url.");

    my $res;
    try {
        $req->authorization_basic($self->user, $self->password);
        my $furl = Furl->new();
        $res = $furl->request($req);

        my $status = $res->code();
        $self->log->debug("Status code $status.");
        return $status;
    }
    catch {
        $self->log->error("Error registering at DataCite: $_\ņHTTP-Result: $res")
    }
}

1;

__END__

=pod

=head1 NAME

LibreCat::Worker::DataCite - a worker for registering and minting at DataCite

=head2 SYNOPSIS

    use LibreCat::Worker::DataCite;

    my $registry = LibreCat::Worker::DataCite->new(user => 'me', password => 'secret');

    $registry->work({
        doi          => '...' ,
        landing_url  => '...' ,
        datacite_xml => '...' ,
    })

    # or call them separately
    $registry->metadata()
    $registry->mint('')

=head2 CONFIGURATION

=over

=item user

Required.

=item password

Required.

=back

=head2 SEE ALSO

L<LibreCat::Worker>

=cut
