package LibreCat::Worker::FileUploader;

use Catmandu::Sane;
use Catmandu::Util;
use IO::File;
use File::Spec;
use Moo;
use namespace::clean;

has files      => (is => 'ro', required => 1);
has temp_files => (is => 'ro', required => 1);
has file_store => (is => 'lazy');
has temp_store => (is => 'lazy');

sub _build_file_store {
    my ($self) = @_;

    my $file_store = $self->files->{package};
    my $file_opts = $self->files->{options} // {};

    my $pkg = Catmandu::Util::require_package($file_store,
        'Catmandu::Store::File');
    $pkg->new(%$file_opts);
}

sub _build_temp_store {
    my ($self) = @_;

    my $temp_store = $self->temp_files->{package};
    my $temp_opts = $self->temp_files->{options} // {};

    my $pkg = Catmandu::Util::require_package($temp_store,
        'Catmandu::Store::File');
    $pkg->new(%$temp_opts);
}

sub work {
    my ($self, $opts) = @_;

    my $key      = $opts->{key}      // '';
    my $filename = $opts->{filename} // '';
    my $tempid   = $opts->{tempid}   // '';

    my $delete = exists $opts->{delete} && $opts->{delete} == 1 ? "Y" : "N";

    $self->log->debug(
        "key: $key ; filename: $filename ; tempid: $tempid ; delete: $delete");

    if ($delete eq 'Y') {
        return $self->do_delete($key, $filename);
    }
    else {
        return $self->do_upload($key, $filename, $tempid);
    }
}

sub do_delete {
    my ($self, $key, $filename) = @_;

    return -1 unless length $key;

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
    my ($self, $key, $filename, $temp_key) = @_;

    return -1 unless length $key;
    return -1 unless length $filename;

    my $temp_file;

    $self->log->info("searching for the temp file $filename in temp container $temp_key");

    if ($self->temp_store->index->exists($temp_key)) {
        $temp_file = $self->temp_store->index->files($temp_key)->get($filename);
    }
    else {
        $self->log->error("failed to find $filename in temp container $temp_key");
        return -1;
    }

    unless ($temp_file) {
        $self->log->error("failed to find $filename in temp container $temp_key");
        return -1;
    }

    $self->log->info("loading container $key");

    unless ($self->file_store->index->exists($key)) {
        $self->log->info("$key not found");
        $self->log->info("creating a new container $key");
        $self->file_store->index->add({_id => $key});
    }

    my $files = $self->file_store->index->files($key);

    $self->log->info("storing $filename in container $key");

    ###
    # Magic to upload temp files via the Catmandu::FileStore
    # in this code we will assume the temporary store is a
    # simple store. For these stores we have a hint where the
    # files are exactly stored.

    unless (ref($self->temp_store) =~ /Catmandu::Store::File::Simple/) {
        $self->log->fatal("sorry I need a File::Simple store to upload data");
        Catmandu::Error->throw("failed to find a File::Simple implementation of the temp store");
    }

    my $temp_bag       = $self->temp_store->index->files($temp_key);
    my $temp_abs_path  = File::Spec->catfile(
                            $temp_bag->_path,
                            $temp_bag->pack_key($filename)
                         );

    my $bytes = $files->upload(IO::File->new("<$temp_abs_path"), $filename);

    $self->log->info("uploaded $bytes bytes");

    my $permanent_file = $self->file_store->index->files($key)->get($filename);

    if ($temp_file->{size} == $permanent_file->{size}) {
        return 1;
    }
    else {
        $self->log->fatal("failed to store $filename in container $key sizes don't match");
        Catmandu::Error->throw("failed to store $filename in container $key sizes don't match");
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
