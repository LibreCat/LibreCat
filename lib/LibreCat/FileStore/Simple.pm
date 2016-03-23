package LibreCat::FileStore::Simple;

use Moo;
use Carp;
use LibreCat::FileStore::Container::Simple;
use feature 'state';
use namespace::clean;

with 'LibreCat::FileStore';

has root => (is => 'ro' , required => '1') ;

sub list {
    my ($self,$callback) = @_;
    my $root = $self->root;
        
    return sub {
        state $io;

        unless (defined($io)) {
            open($io,"find $root -mindepth 3 -maxdepth 4 -type d|");
        }
        
        my $line = <$io>;

        unless (defined($line)) {
            close($io);
            return undef;
        }

        chop($line);
        $line =~ s/$root//;
        $line =~ s/\///g;
        $line;
    };
}

sub exists {
    my ($self,$key) = @_;

    croak "Need a key" unless defined $key;

    $self->log->debug("Checking exists $key");
    
    my $path = path_string($self->root,$key);

    -d $path;
}

sub add {
    my ($self,$key) = @_;

    croak "Need a key" unless defined $key;

    my $path = path_string($self->root,$key);

    unless ($path) {
        $self->log->error("Failed to create path from $key");
        return undef;
    }

    $self->log->debug("Generating path $path for key $key");

    LibreCat::FileStore::Container::Simple->create_container($path,$key);
}

sub get {
    my ($self,$key) = @_;

    croak "Need a key" unless defined $key;

    my $path = path_string($self->root,$key);

    unless ($path) {
        $self->log->error("Failed to create path from $key");
        return undef;
    }

    $self->log->debug("Loading path $path for key $key");

    LibreCat::FileStore::Container::Simple->read_container($path);
}

sub delete {
    my ($self,$key) = @_;

    croak "Need a key" unless defined $key;

    my $path = path_string($self->root,$key);

    unless ($path) {
        $self->log->error("Failed to create path from $key");
        return undef;
    }

    $self->log->debug("Destoying path $path for key $key");

    LibreCat::FileStore::Container::Simple->delete_container($path);
}

sub path_string {
    my ($root,$key) = @_;

    unless ($key =~ /^\d{1,9}$/) {
        return undef;
    }

    my $long_key = sprintf "%-9.9d", $key;
    my $path = $root . "/" . join("/",unpack('(A3)*',$long_key));

    $path;
}

1;

__END__


=pod

=head1 NAME

LibreCat::FileStore::Simple - The default implementation of a file storage

=head1 SYNOPSIS

    use LibreCat::FileStore::Simple;

    my $filestore =>LibreCat::FileStore::Simple->new(root => '/data2/librecat/file_uploads');

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
