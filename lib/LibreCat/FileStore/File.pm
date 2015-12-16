package LibreCat::FileStore::File;

use Moo::Role;
use IO::String;

with 'Catmandu::Logger';

has key           => (is => 'ro' , required => 1);
has content_type  => (is => 'ro');
has size          => (is => 'ro');
has md5           => (is => 'ro');
has created       => (is => 'ro');
has modified      => (is => 'ro');
has data          => (is => 'ro');

sub is_io {
    my $self = shift;
    ref($self->data) =~ /^IO/ ? 1 : 0;
}

sub fh {
    my $self = shift;
    $self->is_io ? $self->data : IO::String->new($self->data);
}

1;

__END__

=pod

=head1 NAME

LibreCat::FileStore::File - Abstract definition of a stored file

=head1 SYNOPSIS

    use LibreCat::FileStore::XYZ;

    my $filestore => LibreCat::FileStore::XYZ->new(%options);

    my $file = $filestore->get('1234')->get('myfile.txt');

	my $filename     = $file->key;
	my $content_type = $file->content_type;
	my $size         = $file->size;
	my $created      = $file->created;
	my $modified     = $file->modified;
	my $data         = $file->data;

	my $fh = $file->data->fh;

=head1 METHODS

=head2 key()

Return the filename.

=head2 content_type()

Return the content type of the file.

=head2 size

Return the byte size of the file.

=head2 created

Return the UNIX creation date of the file.

=head2 modified

Return the UNIX modification date of the file.

=head2 data

Return a IO::Handle for the file.

=head1 SEE ALSO

L<LibreCat::FileStore> , L<LibreCat::FileStore::Container>