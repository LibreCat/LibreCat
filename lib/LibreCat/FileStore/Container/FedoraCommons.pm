package LibreCat::FileStore::Container::FedoraCommons;

use Catmandu::Sane;
use Moo;
use Carp;
use File::Temp;
use File::Copy;
use Date::Parse;
use Digest::MD5;
use LibreCat::MimeType;
use Catmandu::Util;
use Catmandu::Store::FedoraCommons::FOXML;
use LibreCat::FileStore::File::FedoraCommons;
use namespace::clean;

with 'LibreCat::FileStore::Container';

has _fedora   => (is => 'ro');
has _mimeType => (is => 'lazy');

sub _build__mimeType {
    LibreCat::MimeType->new;
}

sub list {
    my ($self)      = @_;
    my $fedora      = $self->_fedora;
    my $ns_prefix   = $fedora->{namespace};
    my $pid         = "$ns_prefix:" . $self->key;
    my $dsnamespace = $fedora->{dsnamespace};

    $self->log->debug("Listing datastreams for $pid");

    my $response = $fedora->listDatastreams(pid => $pid);

    unless ($response->is_ok) {
        $self->log->error("Failed to list datastreams for $pid");
        $self->log->error($response->error);
        return ();
    }

    my $obj = $response->parse_content;

    my @result = ();

    for my $ds (@{$obj->{datastream}}) {
        my $dsid = $ds->{dsid};
        unless ($dsid =~ /^$dsnamespace\./) {
            $self->log->debug("skipping $dsid (not in $dsnamespace)");
            next;
        }

        $self->log->debug("adding $dsid");
        my $file = $self->_get($dsid);
        push @result, $self->_get($dsid) if $file;
    }

    return @result;
}

sub _list_dsid {
    my ($self)      = @_;
    my $fedora      = $self->_fedora;
    my $ns_prefix   = $fedora->{namespace};
    my $pid         = "$ns_prefix:" . $self->key;
    my $dsnamespace = $fedora->{dsnamespace};

    $self->log->debug("Listing datastreams for $pid");

    my $response = $fedora->listDatastreams(pid => $pid);

    unless ($response->is_ok) {
        $self->log->error("Failed to list datastreams for $pid");
        $self->log->error($response->error);
        return ();
    }

    my $obj = $response->parse_content;

    my @result = ();

    for my $ds (@{$obj->{datastream}}) {
        my $dsid  = $ds->{dsid};
        my $label = $ds->{label};

        unless ($dsid =~ /^$dsnamespace\./) {
            $self->log->debug("skipping $dsid (not in $dsnamespace)");
            next;
        }

        $self->log->debug("adding $dsid");
        my $cnt = $dsid;
        $cnt =~ s/^$dsnamespace\.//;
        push @result, {n => $cnt, dsid => $dsid, label => $label};
    }

    return sort {$a->{n} <=> $b->{n}} @result;
}

sub _dsid_by_label {
    my ($self, $key) = @_;
    my $fedora    = $self->_fedora;
    my $ns_prefix = $fedora->{namespace};
    my $pid       = "$ns_prefix:" . $self->key;

    $self->log->debug("Listing datastreams for $pid");
    my $response = $fedora->listDatastreams(pid => $pid);

    unless ($response->is_ok) {
        $self->log->error("Failed to list datastreams for $pid");
        $self->log->error($response->error);
        return ();
    }

    my $obj = $response->parse_content;

    for my $ds (@{$obj->{datastream}}) {
        my $dsid  = $ds->{dsid};
        my $label = $ds->{label};
        return $dsid if $label eq $key;
    }

    return undef;
}

sub exists {
    my ($self, $key) = @_;
    defined($self->_dsid_by_label($key)) ? 1 : undef;
}

sub get {
    my ($self, $key) = @_;

    my $dsid = $self->_dsid_by_label($key);

    return undef unless $dsid;

    return $self->_get($dsid);
}

sub _get {
    my ($self, $dsid) = @_;
    my $fedora    = $self->_fedora;
    my $ns_prefix = $fedora->{namespace};
    my $pid       = "$ns_prefix:" . $self->key;

    $self->log->debug("Get datastream history for $pid:$dsid");
    my $response = $fedora->getDatastreamHistory(pid => $pid, dsID => $dsid);

    unless ($response->is_ok) {
        $self->log->error("Failed to get datastream history for $pid:$dsid");
        $self->log->error($response->error);
        return undef;
    }

    my $object = $response->parse_content;

    my $first = $object->{profile}->[0];
    my $last  = $object->{profile}->[-1];

    return undef unless $first->{dsState} eq 'A';

    my $key          = $first->{dsLabel};
    my $size         = $first->{dsSize};
    my $md5          = $first->{dsChecksum};
    my $content_type = $first->{dsMIME};
    my $created      = str2time($last->{dsCreateDate});
    my $modified     = str2time($first->{dsCreateDate});

    my $data = sub {
        my $io  = shift;
        my $res = $fedora->getDatastreamDissemination(
            pid      => $pid,
            dsID     => $dsid,
            callback => sub {
                my ($data, $response, $protocol) = @_;

                # Support the Dancer send_file "write" callback
                if ($io->can('syswrite')) {
                    $io->syswrite($data);
                }
                else {
                    $io->write($data);
                }
            }
        );
        $io->close;
    };

    LibreCat::FileStore::File::FedoraCommons->new(
        key          => $key,
        size         => $size,
        md5          => $md5 eq 'none' ? '' : $md5,
        created      => $created,
        modified     => $modified,
        content_type => $content_type,
        data         => $data
    );
}

sub add {
    my ($self, $key, $data) = @_;
    my $filename = $self->_io_filename($data);

    if ($filename) {
        return $self->_add_filename($key, $data, $filename);
    }
    else {
        return $self->_add_stream($key, $data);
    }
}

sub _add_filename {
    my ($self, $key, $data, $filename) = @_;
    my $fedora      = $self->_fedora;
    my $ns_prefix   = $fedora->{namespace};
    my $pid         = "$ns_prefix:" . $self->key;
    my $dsnamespace = $fedora->{dsnamespace};
    my $versionable = $fedora->{versionable} ? 'true' : 'false';

    my %options = ('versionable' => $versionable);

    if ($fedora->{md5enabled}) {
        my $ctx      = Digest::MD5->new;
        my $checksum = $ctx->addfile($data)->hexdigest;
        $options{checksum}     = $checksum;
        $options{checksumType} = 'MD5';
    }

    my $mimeType = $self->_mimeType->content_type($key);

    my ($operation, $dsid) = $self->_next_dsid($key);

    my $response;

    if ($operation eq 'ADD') {
        $self->log->debug("Add datastream $pid:$dsid $filename $key $mimeType");
        $response = $fedora->addDatastream(
            pid      => $pid,
            dsID     => $dsid,
            file     => $filename,
            dsLabel  => $key,
            mimeType => $mimeType,
            %options
        );
    }
    else {
        $self->log->debug("Modify datastream $pid:$dsid $filename $key $mimeType");
        $response = $fedora->modifyDatastream(
            pid      => $pid,
            dsID     => $dsid,
            file     => $filename,
            dsLabel  => $key,
            mimeType => $mimeType,
            %options
        );
    }

    unless ($response->is_ok) {
        $self->log->error("Failed to add/modify datastream history for $pid:$dsid");
        $self->log->error($response->error);
        return undef;
    }

    1;
}

sub _add_stream {
    my ($self, $key, $io) = @_;
    my $fedora      = $self->_fedora;
    my $ns_prefix   = $fedora->{namespace};
    my $pid         = "$ns_prefix:" . $self->key;
    my $dsnamespace = $fedora->{dsnamespace};
    my $versionable = $fedora->{versionable} ? 'true' : 'false';

    my ($fh, $filename)
        = File::Temp::tempfile(
        "librecat-filestore-container-fedoracommons-XXXX",
        UNLINK => 1);

    if (Catmandu::Util::is_invocant($io)) {

        # We got a IO::Handle
        File::Copy::cp($io, $filename);
        $io->close;
    }
    else {
        # We got a string
        Catmandu::Util::write_file($filename, $io);
    }

    $fh->close;

    my %options = ('versionable' => $versionable);

    if ($fedora->{md5enabled}) {
        my $ctx      = Digest::MD5->new;
        my $data     = IO::File->new($filename);
        my $checksum = $ctx->addfile($data)->hexdigest;
        $options{checksum}     = $checksum;
        $options{checksumType} = 'MD5';
        $data->close();
    }

    my $mimeType = $self->_mimeType->content_type($key);

    my ($operation, $dsid) = $self->_next_dsid($key);

    my $response;

    if ($operation eq 'ADD') {
        $self->log->debug("Add datastream $pid:$dsid $filename $key $mimeType");
        $response = $fedora->addDatastream(
            pid      => $pid,
            dsID     => $dsid,
            file     => $filename,
            dsLabel  => $key,
            mimeType => $mimeType,
            %options
        );
    }
    else {
        $self->log->debug("Modify datastream $pid:$dsid $filename $key $mimeType");
        $response = $fedora->modifyDatastream(
            pid      => $pid,
            dsID     => $dsid,
            file     => $filename,
            dsLabel  => $key,
            mimeType => $mimeType,
            %options
        );
    }

    unlink $filename;

    unless ($response->is_ok) {
        $self->log->error("Failed to add/modify datastream history for $pid:$dsid");
        $self->log->error($response->error);
        return undef;
    }

    1;
}

sub _next_dsid {
    my ($self, $key) = @_;
    my $fedora      = $self->_fedora;
    my $dsnamespace = $fedora->{dsnamespace};

    my $cnt = -1;

    for ($self->_list_dsid) {
        if ($key eq $_->{label}) {
            return ('MODIFIY', $_->{dsid});
        }
        $cnt = $_->{n};
    }

    return ('ADD', "$dsnamespace." . ($cnt + 1));
}

sub _io_filename {
    my ($self, $data) = @_;

    return undef unless Catmandu::Util::is_invocant($data);

    my $inode = [$data->stat]->[1];
    my $ls    = `ls -i | grep $inode`;
    if ($ls =~ /^\d+\s+(\S.*)/) {
        return $1;
    }
    else {
        return undef;
    }
}

sub delete {
    my ($self, $key) = @_;
    my $fedora    = $self->_fedora;
    my $ns_prefix = $fedora->{namespace};
    my $pid       = "$ns_prefix:" . $self->key;

    my $dsid = $self->_dsid_by_label($key);

    return undef unless $dsid;

    my $response;

    if ($fedora->{purge}) {
        $self->log->debug("Purge datastream $pid:$dsid");
        $response = $fedora->purgeDatastream(pid => $pid, dsID => $dsid);
    }
    else {
        $self->log->debug("Set datastream state D $pid:$dsid");
        $response = $fedora->setDatastreamState(
            pid     => $pid,
            dsID    => $dsid,
            dsState => 'D'
        );
    }

    unless ($response->is_ok) {
        $self->log->error("Failed to purge/set datastream for $pid:$dsid");
        $self->log->error($response->error);
        return undef;
    }

    1;
}

sub commit {
    my ($self) = @_;
}

sub read_container {
    my ($class, $fedora, $key) = @_;
    croak "Need a fedora connection"
        unless $fedora && ref($fedora) eq 'Catmandu::FedoraCommons';
    croak "Need a key" unless $key;

    my $ns_prefix = $fedora->{namespace};

    my $inst = $class->new(key => $key);

    $inst->log->debug("Get object profile $ns_prefix:$key");
    my $response = $fedora->getObjectProfile(pid => "$ns_prefix:$key");

    unless ($response->is_ok) {
        $inst->log->error("Failed get object profile $ns_prefix:$key");
        $inst->log->error($response->error);
        return undef;
    }

    my $object = $response->parse_content;

    $inst->{created}  = str2time($object->{objCreateDate});
    $inst->{modified} = str2time($object->{objLastModDate});
    $inst->{_fedora}  = $fedora;

    $inst;
}

sub create_container {
    my ($class, $fedora, $key) = @_;
    croak "Need a fedora connection"
        unless $fedora && ref($fedora) eq 'Catmandu::FedoraCommons';
    croak "Need a pid" unless $key;

    my $ns_prefix = $fedora->{namespace};

    my $xml = Catmandu::Store::FedoraCommons::FOXML->new->serialize();

    my $inst = $class->new(key => $key);

    $inst->log->debug("Ingest object $ns_prefix:$key");

    my $response = $fedora->ingest(
        pid    => "$ns_prefix:$key",
        xml    => $xml,
        format => 'info:fedora/fedora-system:FOXML-1.1'
    );

    unless ($response->is_ok) {
        $inst->log->error("Failed ingest object $ns_prefix:$key");
        $inst->log->error($response->error);
        return undef;
    }

    my $obj = $response->parse_content;

    $class->read_container($fedora, $key);
}

sub delete_container {
    my ($class, $fedora, $key) = @_;
    croak "Need a fedora connection"
        unless $fedora && ref($fedora) eq 'Catmandu::FedoraCommons';
    croak "Need a key" unless $key;

    my $ns_prefix = $fedora->{namespace};

    my $inst = $class->new(key => $key);

    my $response;

    if ($fedora->{purge}) {
        $class->log->debug("Purge object $ns_prefix:$key");
        $response = $fedora->purgeObject(pid => "$ns_prefix:$key");
    }
    else {
        $class->log->debug("Modify object state D $ns_prefix:$key");
        $response
            = $fedora->modifyObject(pid => "$ns_prefix:$key", state => 'D');
    }

    unless ($response->is_ok) {
        $inst->log->error("Failed purge/modify object $ns_prefix:$key");
        $inst->log->error($response->error);
        return undef;
    }

    1;
}

1;

__END__;

=pod

=head1 NAME

LibreCat::FileStore::Container::FedoraCommons - A FedoraCommons implementation of a file storage container

=head1 SYNOPSIS

    use LibreCat::FileStore::FedoraCommons;

    my %options = (
        url => '...',
        user => '...',
        password => '...' ,
        namespace => 'demo' ,
        dsnamespace => 'DS' ,
        md5enabled => 1 ,
        versionable => 0 ,
    );

    my $filestore => LibreCat::FileStore::FedoraCommons->new(%options);

    my $container = $filestore->get('demo:1234');

    my @list_files = $container->list;

    if ($container->exists($filename)) {
        ....
    }

    $container->add($filename, IO::File->new('/path/to/file'));

    my $file = $container->get($filename);

    $container->delete($filename);

    # write all changes to disk (network , database , ...)
    $container->commit;

=head1 SEE ALSO

L<LibreCat::FileStore::Container>
