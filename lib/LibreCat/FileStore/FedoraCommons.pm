package LibreCat::FileStore::FedoraCommons;

use Moo;
use Carp;
use Catmandu::FedoraCommons;
use LibreCat::FileStore::Container::FedoraCommons;
use feature 'state';
use namespace::clean;

with 'LibreCat::FileStore';

has url         => (is => 'ro' , default => sub { 'http://localhost:8080/fedora' }) ;
has user        => (is => 'ro' , default => sub { 'fedoraAdmin'} ) ;
has password    => (is => 'ro' , default => sub { 'fedoraAdmin'} ) ;
has namespace   => (is => 'ro' , default => sub { 'demo' });
has dsnamespace => (is => 'ro' , default => sub { 'DS' } );
has md5enabled  => (is => 'ro' , default => sub { '1'} );
has versionable => (is => 'ro' , default => sub { '0'} );
has fedora      => (is => 'lazy') ;

sub _build_fedora {
    my ($self) = @_;
    my $fedora = Catmandu::FedoraCommons->new($self->url,$self->user,$self->password);
    $fedora->{dsnamespace} = $self->dsnamespace;
    $fedora->{md5enabled}  = $self->md5enabled;
    $fedora->{versionable} = $self->versionable;
    $fedora;
}

sub list {
    my ($self,$callback) = @_;
    my $fedora = $self->fedora;
        
    return sub {
        state $hits;
        state $row;
        state $ns_prefix = $self->namespace;
         
        if( ! defined $hits) {
            my $res = $fedora->findObjects( query => "pid~${ns_prefix}*" );
            unless ($res->is_ok) {
                warn $res->error;
                return undef;
            }
            $row  = 0;
            $hits = $res->parse_content;
        }
        if ($row + 1 == @{ $hits->{results} } && defined $hits->{token}) {
            my $result = $hits->{results}->[ $row ];
             
            my $res = $fedora->findObjects(sessionToken => $hits->{token});
             
            unless ($res->is_ok) {
                warn $res->error;
                return undef;
            }
             
            $row  = 0;
            $hits = $res->parse_content;
             
            return $result->{pid};
        }  
        else {
            my $result = $hits->{results}->[ $row++ ];
            return $result->{pid};
        }
    };
}

sub exists {
    my ($self,$key) = @_;

    croak "Need a key" unless defined $key;

    $self->log->debug("Checking exists $key");

    my $obj = $self->fedora->getObjectProfile(pid => $key);

    $obj->is_ok;
}

sub add {
    my ($self,$key) = @_;

    croak "Need a key" unless defined $key;

    $self->log->debug("Generating path container for key $key");

    LibreCat::FileStore::Container::BagIt->create_container($self->fedora,$key);
}

sub get {
    my ($self,$key) = @_;

    croak "Need a key" unless defined $key;

    $self->log->debug("Loading container for $key");

    LibreCat::FileStore::Container::FedoraCommons->read_container($self->fedora,$key);
}

sub delete {
    my ($self,$key) = @_;

    croak "Need a key" unless defined $key;

    LibreCat::FileStore::Container::BagIt->delete_container($self->fedora,$key);
}

1;

__END__


=pod

=head1 NAME

LibreCat::FileStore::BagIt - A BagIt implementation of a file storage

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

    my $filestore =>LibreCat::FileStore::BagIt->new(%options);

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
