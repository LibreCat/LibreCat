package LibreCat::Worker::FileUploader;

use Catmandu::Sane;
use Catmandu::Util;
use IO::File;
use Moo;
use namespace::clean;

with 'LibreCat::Worker';

has files => (is => 'ro', required => 1);
has file_store => (is => 'lazy');

sub _build_file_store {
    my ($self) = @_;

    my $file_store = $self->files->{package};
    my $file_opts = $self->files->{options} // {};

    my $pkg
        = Catmandu::Util::require_package($file_store, 'Catmandu::Store::File');
    $pkg->new(%$file_opts);
}

sub work {
    my ($self, $opts) = @_;

    my $key      = $opts->{key};
    my $filename = $opts->{filename};
    my $path     = $opts->{path};
    $key      = '' unless $key;
    $filename = '' unless $filename;
    $path     = '' unless $path;
    my $delete = exists $opts->{delete} && $opts->{delete} == 1 ? "Y" : "N";

    $self->log->debug(
        "key: $key ; filename: $filename ; path: $path ; delete: $delete");

    if ($delete eq 'Y') {
        return $self->do_delete($key, $filename, $path, %$opts);
    }
    else {
        return $self->do_upload($key, $filename, $path, %$opts);
    }
}

sub do_delete {
    my ($self, $key, $filename, $path, %opts) = @_;

    return -1 unless length $key && $key =~ /^\d+$/;

    $self->log->info("loading container $key");

    unless ($self->file_store->index->exists($key)) {
        $self->log->error("$key not found");
        return -1;
    }

    my $files = $self->file_store->index->files($key);

    if (defined $filename) {
        $self->log->info("deleting $filename from container $key");
        return $files->delete($filename);
    }
    else {
        $self->log->info("deleting container $key");
        return $self->file_store->index->delete($key);
    }
}

sub do_upload {
    my ($self, $key, $filename, $path, %opts) = @_;

    return -1 unless length $key && $key =~ /^[0-9A-F-]+$/;
    return -1 unless length $filename;
    return -1 unless length $path && -f $path && -r $path;

    $self->log->info("loading container $key");

    unless ($self->file_store->index->exists($key)) {
        $self->log->info("$key not found");
        $self->log->info("creating a new container $key");
        $self->file_store->index->add({ _id => $key });
    }

    my $files = $self->file_store->index->files($key);

    $self->log->info("storing $filename in container $key");

    my $bytes = $files->upload(IO::File->new($path), $filename);

    $self->log->info("uploaded $bytes bytes");

    if ($bytes) {
        return 1;
    }
    else {
        $self->log->error("failed to store $filename in container $key");
        return -1;
    }
}

1;

__END__

=pod

=head1 NAME

LibreCat::Worker::FileUploader - a worker for uploading files into the repostitory

=head2 SYNOPSIS

    use LibreCat::Worker::FileUploader;

    my $uploader = LibreCat::Worker::FileUploader->new(
                    files => {
                        package => 'Simple',
                        options => {
                            root => '/data2/librecat/file_uploads'
                        }
                   });

    $uploader->work({
        key      => $key,
        filename => $filename,
        path     => $filepath,
        [ delete => 1]
    });

=head2 CONFIGURATION

=over

=item files

Required. The Catmandu::Store::File implementation to use.

=back

=head2 SEE ALSO

L<LibreCat::Worker>

=cut
