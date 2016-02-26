package LibreCat::FileStore::Container::FedoraCommons;

use Moo;
use Carp;
use File::Temp;
use File::Copy;
use Date::Parse;
use Digest::MD5;
use Catmandu::Store::FedoraCommons::FOXML;
use LibreCat::FileStore::File::FedoraCommons;

use namespace::clean;

with 'LibreCat::FileStore::Container';

has _fedora => (is => 'ro');

sub list {
    my ($self) = @_;
    my $fedora  = $self->_fedora;
    my $ns_prefix = $fedora->{namespace};
    my $pid     = "$ns_prefix:" . $self->key;
    my $dsnamespace = $fedora->{dsnamespace};

    my $response = $fedora->listDatastreams(pid => $pid);

    return () unless $response->is_ok;

    my $obj = $response->parse_content;

    my @result = ();

    for my $ds (@{ $obj->{datastream} }) {
        my $dsid = $ds->{dsid};
        next unless $dsid =~ /^$dsnamespace\./;
        my $file = $self->_get($dsid);
        push @result , $self->_get($dsid) if $file;
    }

    return @result;
}

sub _list_dsid {
    my ($self) = @_;
    my $fedora  = $self->_fedora;
    my $ns_prefix = $fedora->{namespace};
    my $pid     = "$ns_prefix:" . $self->key;
    my $dsnamespace = $fedora->{dsnamespace};

    my $response = $fedora->listDatastreams(pid => $pid);

    return () unless $response->is_ok;

    my $obj = $response->parse_content;

    my @result = ();

    for my $ds (@{ $obj->{datastream} }) {
        my $dsid  = $ds->{dsid};
        my $label = $ds->{label};
        next unless $dsid =~ /^$dsnamespace\./;
        my $cnt   = $dsid;
        $cnt =~ s/^$dsnamespace\.//;
        push @result , { n => $cnt , dsid => $dsid , label => $label };
    }

    return sort { $a->{n} <=> $b->{n} } @result;
}

sub _dsid_by_label {
    my ($self,$key) = @_;
    my $fedora  = $self->_fedora;
    my $ns_prefix = $fedora->{namespace};
    my $pid     = "$ns_prefix:" . $self->key;

    my $response = $fedora->listDatastreams(pid => $pid);

    return undef unless $response->is_ok;

    my $obj = $response->parse_content;

    for my $ds (@{ $obj->{datastream} }) {
        my $dsid  = $ds->{dsid};
        my $label = $ds->{label};
        return $dsid if $label eq $key;
    }

    return undef;
}

sub exists {
    my ($self,$key) = @_;
    defined($self->_dsid_by_label($key)) ? 1 : undef;
}

sub get {
    my ($self,$key) = @_;
    
    my $dsid = $self->_dsid_by_label($key);

    return undef unless $dsid;

    return $self->_get($dsid);
}

sub _get {
    my ($self,$dsid) = @_;
    my $fedora  = $self->_fedora;
    my $ns_prefix = $fedora->{namespace};
    my $pid     = "$ns_prefix:" . $self->key;

    my $response = $fedora->getDatastreamHistory(pid => $pid , dsID => $dsid);

    return undef unless $response->is_ok;

    my $object = $response->parse_content;

    my $first    = $object->{profile}->[0];
    my $last     = $object->{profile}->[-1];

    return undef unless $first->{dsState} eq 'A';

    my $key      = $first->{dsLabel};
    my $size     = $first->{dsSize};
    my $md5      = $first->{dsChecksum};
    my $created  = str2time($last->{dsCreateDate});
    my $modified = str2time($first->{dsCreateDate});
    my $data     = undef;

    LibreCat::FileStore::File::FedoraCommons->new(
            key      => $key ,
            size     => $size ,
            md5      => $md5  eq 'none' ? '' : $md5,
            created  => $created ,
            modified => $modified ,
            data     => $data 
    );
}

sub add {
    my ($self,$key,$data) = @_;
    my $filename = $self->_io_filename($data);

    if ($filename) {
        return $self->_add_filename($key,$data,$filename);
    }
    else {
        return $self->_add_stream($key,$data);
    }
}

sub _add_filename {
    my ($self,$key,$data,$filename) = @_;
    my $fedora  = $self->_fedora;
    my $ns_prefix = $fedora->{namespace};
    my $pid     = "$ns_prefix:" . $self->key;
    my $dsnamespace = $fedora->{dsnamespace};
    my $versionable = $fedora->{versionable} ? 'true' : 'false';

    my %options = ( 'versionable' => $versionable );

    if ($fedora->{md5enabled}) {
        my $ctx = Digest::MD5->new;
        my $checksum = $ctx->addfile($data)->hexdigest;
        $options{checksum} = $checksum;
        $options{checksumType} = 'MD5';
    }

    my ($operation,$dsid) = $self->_next_dsid($key);

    my $response;

    if ($operation eq 'ADD') {
        $response = $fedora->addDatastream(
                        pid => $pid , 
                        dsID => $dsid , 
                        file => $filename, 
                        dsLabel => $key,
                        %options
                        );
    } 
    else {
        $response = $fedora->modifyDatastream(
                        pid => $pid , 
                        dsID => $dsid , 
                        file => $filename, 
                        dsLabel => $key,
                        %options
                        ); 
    }

    return undef unless $response->is_ok;

    1; 
}

sub _add_stream {
    my ($self,$key,$io) = @_;
    my $fedora  = $self->_fedora;
    my $ns_prefix = $fedora->{namespace};
    my $pid     = "$ns_prefix:" . $self->key;
    my $dsnamespace = $fedora->{dsnamespace};
    my $versionable = $fedora->{versionable}  ? 'true' : 'false' ;

    my ($fh,$filename) = File::Temp::tempfile("librecat-filestore-container-fedoracommons-XXXX", UNLINK => 1);

    File::Copy::cp($io,$filename);

    $io->close;
    $fh->close;

    my %options = ( 'versionable' => $versionable );

    if ($fedora->{md5enabled}) {
        my $ctx  = Digest::MD5->new;
        my $data = IO::File->new($filename);
        my $checksum = $ctx->addfile($data)->hexdigest;
        $options{checksum} = $checksum;
        $options{checksumType} = 'MD5';
        $data->close();
    }

    my ($operation,$dsid) = $self->_next_dsid($key);

    my $response;

    if ($operation eq 'ADD') {
        $response = $fedora->addDatastream(
                        pid => $pid , 
                        dsID => $dsid , 
                        file => $filename, 
                        dsLabel => $key ,
                        %options
                        );
    }
    else {
        $response = $fedora->modifyDatastream(
                        pid => $pid , 
                        dsID => $dsid , 
                        file => $filename, 
                        dsLabel => $key ,
                        %options
                        );
    }

    unlink $filename;

    return undef unless $response->is_ok;

    1;    
}

sub _next_dsid {
    my ($self,$key) = @_;
    my $fedora  = $self->_fedora;
    my $dsnamespace = $fedora->{dsnamespace};
    
    my $cnt  = -1;

    for ($self->_list_dsid) {
        if ($key eq $_->{label}) {
            return ('MODIFIY',$_->{dsid});
        }
        $cnt = $_->{n};
    }
    
    return ('ADD',"$dsnamespace." . ($cnt + 1));
}

sub _io_filename {
    my ($self,$data) = @_;

    my $inode = [$data->stat]->[1];
    my $ls  = `ls -i | grep $inode`;
    if ($ls =~ /^\d+\s+(\S.*)/) {
        return $1;
    }
    else {
        return undef;
    }
}

sub delete {
    my ($self,$key) = @_;
    my $fedora  = $self->_fedora;
    my $ns_prefix = $fedora->{namespace};
    my $pid     = "$ns_prefix:" . $self->key;

    my $dsid = $self->_dsid_by_label($key);

    return undef unless $dsid;

    my $response;

    if ($fedora->{purge}) {
        $response = $fedora->purgeDatastream(pid => $pid , dsID => $dsid);
    }
    else {
        $response = $fedora->setDatastreamState(pid => $pid , dsID => $dsid, dsState => 'D');
    }

    return $response->is_ok ? 1 : undef;
}

sub commit {
    my ($self) = @_;
}

sub read_container {
    my ($class,$fedora,$key) = @_;
    croak "Need a fedora connection" unless $fedora && ref($fedora) eq 'Catmandu::FedoraCommons';
    croak "Need a key" unless $key;

    my $ns_prefix = $fedora->{namespace};

    my $response = $fedora->getObjectProfile(pid => "$ns_prefix:$key");

    return undef unless $response->is_ok;

    my $object = $response->parse_content;

    my $inst = $class->new(key  => $key);

    $inst->{created}  = str2time($object->{objCreateDate});
    $inst->{modified} = str2time($object->{objLastModDate});
    $inst->{_fedora}  = $fedora;

    $inst;
}

sub create_container {
    my ($class,$fedora,$key) = @_;
    croak "Need a fedora connection" unless $fedora && ref($fedora) eq 'Catmandu::FedoraCommons';
    croak "Need a pid" unless $key;

    my $ns_prefix = $fedora->{namespace};

    my $xml = Catmandu::Store::FedoraCommons::FOXML->new->serialize();

    my $response = $fedora->ingest(pid => "$ns_prefix:$key" , xml => $xml , format => 'info:fedora/fedora-system:FOXML-1.1');

    return undef unless $response->is_ok;

    my $obj = $response->parse_content;

    $class->read_container($fedora, $key);
}

sub delete_container {
    my ($class,$fedora,$key) = @_;
    croak "Need a fedora connection" unless $fedora && ref($fedora) eq 'Catmandu::FedoraCommons';
    croak "Need a key" unless $key;

    my $ns_prefix = $fedora->{namespace};

    my $response;

    if ($fedora->{purge}) {
        $response = $fedora->purgeObject(pid => "$ns_prefix:$key");
    }
    else {
        $response = $fedora->modifyObject(pid => "$ns_prefix:$key", state => 'D');
    }

    return undef unless $response->is_ok;

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