package LibreCat::FileStore::FedoraCommons;

use Catmandu::Sane;
use Moo;
use Carp;
use Catmandu::FedoraCommons;
use LibreCat::FileStore::Container::FedoraCommons;
use Data::UUID;
use namespace::clean;

with 'LibreCat::FileStore';

has url      => (is => 'ro', default => sub {'http://localhost:8080/fedora'});
has user     => (is => 'ro', default => sub {'fedoraAdmin'});
has password => (is => 'ro', default => sub {'fedoraAdmin'});
has namespace   => (is => 'ro', default => sub {'demo'});
has dsnamespace => (is => 'ro', default => sub {'DS'});
has md5enabled  => (is => 'ro', default => sub {'1'});
has versionable => (is => 'ro', default => sub {'0'});
has purge       => (is => 'ro', default => sub {'0'});
has fedora      => (is => 'lazy');

sub _build_fedora {
    my ($self) = @_;
    my $fedora = Catmandu::FedoraCommons->new($self->url, $self->user,
        $self->password);
    $fedora->{namespace}   = $self->namespace;
    $fedora->{dsnamespace} = $self->dsnamespace;
    $fedora->{md5enabled}  = $self->md5enabled;
    $fedora->{versionable} = $self->versionable;
    $fedora->{purge}       = $self->purge;
    $fedora;
}

sub list {
    my ($self, $callback) = @_;
    my $fedora = $self->fedora;

    $self->log->debug("creating generator for Fedora @ " . $self->url);

    return sub {
        state $hits;
        state $row;
        state $ns_prefix = $self->namespace;

        if (!defined $hits) {
            my $res
                = $fedora->findObjects(query => "pid~${ns_prefix}* state=A");
            unless ($res->is_ok) {
                $self->log->error($res->error);
                return undef;
            }
            $row  = 0;
            $hits = $res->parse_content;
        }
        if ($row + 1 == @{$hits->{results}} && defined $hits->{token}) {
            my $result = $hits->{results}->[$row];

            my $res = $fedora->findObjects(sessionToken => $hits->{token});

            unless ($res->is_ok) {
                warn $res->error;
                return undef;
            }

            $row  = 0;
            $hits = $res->parse_content;

            my $pid = $result->{pid};
            $pid =~ s{^$ns_prefix:}{} if $pid;

            return $pid;
        }
        else {
            my $result = $hits->{results}->[$row++];

            my $pid = $result->{pid};
            $pid =~ s{^$ns_prefix:}{} if $pid;

            return $pid;
        }
    };
}

sub exists {
    my ($self, $key) = @_;
    my $ns_prefix = $self->namespace;

    croak "Need a key" unless defined $key;

    $self->log->debug("Checking exists $key");

    my $long_key = $self->_long_key($key);

    my $obj = $self->fedora->getObjectProfile(pid => "$ns_prefix:$long_key");

    $obj->is_ok;
}

sub add {
    my ($self, $key) = @_;

    croak "Need a key" unless defined $key;

    if ($key =~ /^new$/i) {
        $self->log->debug("Generating new key...");
        $key = $self->_generate_key;
        $self->log->debug("key = $key");
    }

    $self->log->debug("Generating path container for key $key");

    my $long_key = $self->_long_key($key);

    LibreCat::FileStore::Container::FedoraCommons->create_container(
        $self->fedora, $long_key);
}

sub get {
    my ($self, $key) = @_;

    croak "Need a key" unless defined $key;

    $self->log->debug("Loading container for $key");

    my $long_key = $self->_long_key($key);

    LibreCat::FileStore::Container::FedoraCommons->read_container(
        $self->fedora, $long_key);
}

sub delete {
    my ($self, $key) = @_;

    croak "Need a key" unless defined $key;

    my $long_key = $self->_long_key($key);

    LibreCat::FileStore::Container::FedoraCommons->delete_container(
        $self->fedora, $long_key);
}

sub _generate_key {
    my $ug = Data::UUID->new;
    my $uuid = $ug->create();
    return $ug->to_string($uuid);
}

sub _long_key {
    my ($selk, $key) = @_;
    if ($key =~ /^\d+$/) {
        return sprintf "%-9.9d", $key;
    }
    else {
        return $key;
    }
}
1;

__END__


=pod

=head1 NAME

LibreCat::FileStore::FedoraCommons - A FedoraCommons 3.X implementation of a file storage

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
        purge => 1 ,
    );

    my $filestore =>LibreCat::FileStore::FedoraCommons->new(%options);

    my $generator = $filestore->list;

    while (my $key = $generator->()) {
        my $container = $filestore->get($key);

        for my $file ($container->list) {
            my $filename = $file->key;
            my $size     = $file->size;
            my $checksum = $file->md5;
            my $created  = $file->created;
            my $modified = $file->modified;
            my $io       = $file->data;
        }
    }

    my $container = $filestore->get('1234');

    if ($filestore->exists('1234')) {
        ...
    }

    my $container = $filestore->add('1235');

    $filestore->delete('1234');

=head1 SEE ALSO

L<LibreCat::FileStore>
