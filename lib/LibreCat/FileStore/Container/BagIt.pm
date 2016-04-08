package LibreCat::FileStore::Container::BagIt;

use Moo;
use Carp;
use File::Path;
use Catmandu::BagIt;
use URI::Escape;
use LibreCat::FileStore::File::BagIt;

use namespace::clean;

with 'LibreCat::FileStore::Container';

has _bagit => (is => 'ro');

sub list {
    my ($self) = @_;
    my $bagit  = $self->_bagit;
    my $path = $bagit->path;

    my @result = ();

    for my $file ($bagit->list_files) {
        my $unpacked_key = $self->unpack_key($file->filename);
        push @result , $self->get($unpacked_key);
    }

    return @result;
}

sub exists {
    my ($self,$key) = @_;
    my $bagit  = $self->_bagit;

    defined $bagit->get_file($key);
}

sub get {
    my ($self,$key) = @_;
    my $bagit  = $self->_bagit;

    my $packed_key = $self->pack_key($key);

    my $file = $bagit->get_file($packed_key);

    return undef unless $file;

    my $data     = $file->fh;
    my $md5      = $bagit->get_checksum($key);
    my $stat     = [$file->fh->stat];

    my $size     = $stat->[7];
    my $modified = $stat->[9];
    my $created  = $stat->[10]; # no real creation time exists on Unix

    LibreCat::FileStore::File::BagIt->new(
            key      => $key ,
            size     => $size ,
            md5      => $md5 ,
            created  => $created ,
            modified => $modified ,
            data     => $data 
    );
}

sub add {
    my ($self,$key,$data) = @_;
    my $bagit  = $self->_bagit; 

    my $packed_key = $self->pack_key($key);

    $bagit->add_file($packed_key,$data);
}

sub delete {
    my ($self,$key) = @_;
    my $bagit  = $self->_bagit; 

    my $packed_key = $self->pack_key($key);

    $bagit->remove_file($packed_key);
}

sub commit {
    my ($self) = @_;
    my $bagit  = $self->_bagit; 
    my $path   = $bagit->path;

    $bagit->write($path, overwrite => 1);

    $self->{_bagit} = Catmandu::BagIt->read($path);
}

sub read_container {
    my ($class,$path) = @_;
    croak "Need a path" unless $path;

    my $bagit = Catmandu::BagIt->read($path);

    return undef unless $bagit;

    my $key = $bagit->get_info('Archive-Id');

    return undef unless $key;

    my $inst = $class->new(key  => $key);

    $inst->{created}  = $bagit->get_info('Unix-Creation-Time');
    $inst->{modified} = $bagit->get_info('Unix-Modification-Time');
    $inst->{_bagit}   = $bagit;

    $inst;
}

sub create_container {
    my ($class,$path,$key) = @_;

    croak "Need a path and a key" unless $path && $key;

    my $bagit = Catmandu::BagIt->new();

    $bagit->add_info('Archive-Id' => $key);
    $bagit->add_info('Unix-Creation-Time' => time);
    $bagit->add_info('Unix-Modification-Time' => time);

    $bagit->write($path , overwrite => 1);

    $class->read_container($path);
}

sub delete_container {
    my ($class,$path) = @_;

    croak "Need a path" unless $path;

    return undef unless -d $path;

    File::Path::remove_tree($path);
}

sub pack_key {
    my $self = shift;
    my $key  = shift;
    uri_escape($key);
}

sub unpack_key {
    my $self = shift;
    my $key  = shift;
    uri_unescape($key);
}

1;

__END__;

=pod

=head1 NAME

LibreCat::FileStore::Container::BagIt - A BagIt implementation of a file storage container

=head1 SYNOPSIS

    use LibreCat::FileStore::BagIt;

    my $filestore => LibreCat::FileStore::BagIt->new(%options);

    my $container = $filestore->get('1234');

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