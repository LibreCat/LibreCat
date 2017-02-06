package LibreCat::FileStore::File;

use Catmandu::Sane;
use Moo::Role;
use IO::String;
use IO::Pipe;
use namespace::clean;

$SIG{CHLD} = 'IGNORE';

has key => (is => 'ro', required => 1);
has content_type => (is => 'ro');
has size         => (is => 'ro');
has md5          => (is => 'ro');
has created      => (is => 'ro');
has modified     => (is => 'ro');
has data         => (is => 'ro');

sub fh {
    my $self = shift;

    if (ref($self->data) =~ /^IO/) {
        $self->data;
    }
    elsif ($self->is_callback) {
        $self->io_from_callback($self->data);
    }
    elsif ($self->is_url) {
        $self->io_from_url($self->data);
    }
    else {
        IO::String->new($self->data);
    }
}

sub is_url {
    my $self = shift;
    $self->data =~ /^http/i;
}

sub is_callback {
    my $self = shift;
    ref($self->data) eq 'CODE'
}

sub io_from_url {
    my $self = shift;
    my $url  = shift;

    IO::Pipe->reader("curl -s \"$url\"");
}

sub io_from_callback {
    my $self     = shift;
    my $callback = shift;

    my $pid;
    my $pipe = new IO::Pipe;

    if ($pid = fork()) {    # parent
        $pipe->reader();
        return $pipe;
    }
    elsif (defined($pid)) {    # child
        $pipe->writer;
        $callback->($pipe);
        $pipe->close;
        exit;
    }
}

1;

__END__

=pod

=head1 NAME

LibreCat::FileStore::File - Abstract definition of a stored file

=head1 SYNOPSIS

    use LibreCat::FileStore::Simple;

    my $filestore => LibreCat::FileStore::Simple->new(%options);

    my $file = $filestore->get('1234')->get('myfile.txt');

    my $filename     = $file->key;
    my $content_type = $file->content_type;
    my $size         = $file->size;
    my $created      = $file->created;
    my $modified     = $file->modified;

    my $fh = $file->fh;

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
