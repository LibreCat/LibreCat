package LibreCat::Worker::DataCite;

use Catmandu::Sane;
use LWP;
use Crypt::SSLeay;
use Term::ReadKey;
use URI;
use URI::Escape;
use Encode qw(encode_utf8);
use Moo;
use namespace::clean;

with 'LibreCat::Worker';

has base_url => (is => 'ro', default => sub {'https://mds.datacite.org'});
has user     => (is => 'ro', required => 1);
has password => (is => 'ro', required => 1);
has test_mode => (is => 'ro');

# TODO return values
sub work {
    my ($self, $opts) = @_;

    $self->metadata($opts->{doi}, $opts->{datacite_xml});
    $self->mint($opts->{doi}, $opts->{landing_url});
}

sub mint {
    my ($self, $doi, $landing_url) = @_;

    $self->log->debug("Minting $doi to $landing_url.");

    $self->_do_request('POST', $self->base_url . "/doi",
        "doi=$doi\nurl=$landing_url", 'text/plain;charset=UTF-8',);
}

sub metadata {
    my ($self, $doi, $datacite_xml) = @_;

    $self->log->debug("Register metadata for $doi. XML: $datacite_xml.");

    $self->_do_request(
        'POST',        $self->base_url . "/metadata",
        $datacite_xml, 'application/xml;charset=UTF-8',
    );
}

sub _do_request {
    my ($self, $method, $url, $content, $content_type) = @_;

    $content .= "\ntestMode=true" if $self->test_mode;
    my $headers = HTTP::Headers->new(
        Accept         => 'application/xml',
        'Content-Type' => $content_type,
    );

    my $req = HTTP::Request->new($method => $url, $headers,
        encode_utf8($content));

    $self->log->debug("Sending $method request to $url.");

    $req->authorization_basic($self->user, $self->password);
    my $ua  = LWP::UserAgent->new;
    my $res = $ua->request($req);

    my $status = $res->code();
    $self->log->debug("Status code $status.");
    return $status;
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
