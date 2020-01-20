package LibreCat::Worker::Datacite;

use Catmandu::Sane;
use Catmandu;
use LibreCat -self;
use Furl;
use HTTP::Headers;
use HTTP::Request;
use URI;
use Encode qw(encode_utf8);
use Try::Tiny;
use IO::Socket::SSL;
use Moo;
use namespace::clean;

has base_url  => (is => 'lazy');
has user      => (is => 'ro', required => 1);
has password  => (is => 'ro', required => 1);
has test_mode => (is => 'ro');
has timeout   => (is => 'ro', default => sub {return 10});

sub _build_base_url {
    my $self = shift;
    $self->test_mode
        ? return 'https://mds.test.datacite.org'
        : return 'https://mds.datacite.org';
}

sub work {
    my ($self, $opts) = @_;

    my $metadata = $self->metadata($opts->{doi}, $opts->{record});
    my $mint     = $self->mint($opts->{doi}, $opts->{landing_url});

    return {metadata => $metadata, mint => $mint};
}

sub mint {
    my ($self, $doi, $landing_url) = @_;

    return unless $doi && $landing_url;

    $self->log->debug("Minting $doi to $landing_url.");

    my $uri = URI->new($self->base_url);
    $uri->path("/doi/$doi");
    $self->_do_request('PUT', $uri->as_string, "doi=$doi\nurl=$landing_url",
        'text/plain;charset=UTF-8',);
}

sub metadata {
    my ($self, $doi, $rec) = @_;

    return unless $doi && $rec;

    $self->log->debug("Register metadata for $doi.");

    my $datacite_xml = $self->_create_metadata($rec);

    my $uri = URI->new($self->base_url);
    $uri->path("/metadata");
    $uri->query_form(testMode => $self->test_mode ? 'true' : 'false',);

    $self->_do_request('POST', $uri->as_string, $datacite_xml,
        'application/xml;charset=UTF-8',
    );
}

sub _create_metadata {
    my ($self, $rec) = @_;

    my $datacite_xml = Catmandu->export_to_string(
        {%$rec, uri_base => librecat->config->{uri_base}}, 'Template',
        template => 'views/export/datacite.tt',
        fix      => librecat->fixer('to_datacite.fix'),
        xml      => 1
    );
    $self->log->error($datacite_xml);
    return $datacite_xml;
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
        my $furl = Furl->new(timeout => $self->timeout);
        $res = $furl->request($req);

        my $status = $res->code();
        $self->log->debug("Status code $status.");
        return $status;
    }
    catch {
        $self->log->error("Error registering at DataCite: $_\ņ")
    }
}

1;

__END__

=pod

=head1 NAME

LibreCat::Worker::Datacite - a worker for registering and minting DOIs at DataCite

=head2 SYNOPSIS

    use LibreCat::Worker::Datacite;

    my $registry_worker = LibreCat::Worker::Datacite->new(
        user => 'me',
        password => 'secret',
        timeout => 20, # optional
        test_mode => 0, # optional
        );

    $registry_worker->work({
        doi          => '...' ,
        landing_url  => '...' ,
        record => $record_hash ,
    })

    # or better queue it via LibreCat

    use LibreCat -self;

    my $job = {
        doi => '...',
        landing_url => '...',
        record => $record_hash,
    };

    librecat->queue->add('datacite', $job);

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
