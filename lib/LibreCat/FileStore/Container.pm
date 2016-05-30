package LibreCat::FileStore::Container;

use Moo::Role;

with 'Catmandu::Logger';

has key        => (is => 'ro' , required => 1);
has created    => (is => 'ro');
has modified   => (is => 'ro');

requires 'list';
requires 'exists';
requires 'add';
requires 'get';
requires 'delete';
requires 'commit';

1;

__END__

=pod

=head1 NAME

LibreCat::FileStore::Container - Abstract definition of a file storage container

=head1 SYNOPSIS

    use LibreCat::FileStore::Simple;

    my $filestore => LibreCat::FileStore::Simple->new(%options);

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

=head1 DESCRIPTION

LibreCat::FileStore::Container is an abstract definition of a storage container. 
These container are used to store zero or more LibreCat::FileStore::Files.

=head1 METHODS

=head2 get($key)

Retrieve a LibreCat::FileStore::File based on a $key. Returns a LibreCat::FileStore::File on 
success or undef on failure.

=head2 add($filename, IO::File->new(...))

Add a new LibreCat::FileStore::File file to the container. Return 1 on success or undef on failure.

Based on the implementation of LibreCat::FileStore, the files might only be available when changes
have been committed.

=head2 commit()

Commit all changes to the container (write to disk).

=head2 delete($filename)

Delete a $filename from the container.

=head2 exists($filename)

Check if a $filename exists in the container.

=head1 SEE ALSO

L<LibreCat::FileStore> , L<LibreCat::FileStore::File>