package LibreCat::FileStore;

use Catmandu::Sane;
use Moo::Role;
use Carp;
use namespace::clean;

with 'Catmandu::Logger';

requires 'list';
requires 'exists';
requires 'add';
requires 'get';
requires 'delete';

1;

__END__

=pod

=head1 NAME

LibreCat::FileStore - Abstract definition of a file storage implementation

=head1 SYNOPSIS

    use LibreCat::FileStore::XYZ;

    my $filestore => LibreCat::FileStore::XYZ->new(%options);

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

=head1 DESCRIPTION

LibreCat::FileStore is an abstract definition of a file storage. File content is
stored in a container given by an identifier. Each container can contain zero
or more files.

=head1 METHODS

=head2 new(%options)

Create a new LibreCat::FileStore.

=head2 list()

Provide a listing of all available container keys. Returns an iterator with keys.

=head2 get($key)

Return a LibreCat::FileStore::Container given a $key.

=head2 add($key)

Creates a new container and returns a LibreCat::FileStore::Container.

=head2 delete($key)

Removed a container from the system.

=head1 SEE ALSO

L<LibreCat::FileStore::Container> , L<LibreCat::FileStore::File>