package LibreCat::Worker::ImageResizer;

use Catmandu::Sane;
use Catmandu::Util;
use Data::Uniqid;
use File::Spec;
use Moo;
use namespace::clean;

with 'LibreCat::Worker';

has files          => (is => 'ro', required => 1);
has access         => (is => 'ro', required => 1);
has tmpdir         => (is => 'ro', default  => sub {'/tmp'});
has buffer_size    => (is => 'ro', default  => sub {8192});
has thumbnail_size => (is => 'ro', default  => sub {200});
has file_store   => (is => 'lazy');
has access_store => (is => 'lazy');

sub _build_file_store {
    my ($self) = @_;

    my $file_store = $self->files->{package};
    my $file_opts = $self->files->{options} // {};

    my $pkg
        = Catmandu::Util::require_package($file_store, 'LibreCat::FileStore');
    $pkg->new(%$file_opts);
}

sub _build_access_store {
    my ($self) = @_;

    my $file_store = $self->access->{package};
    my $file_opts = $self->access->{options} // {};

    my $pkg
        = Catmandu::Util::require_package($file_store, 'LibreCat::FileStore');
    $pkg->new(%$file_opts);
}

sub work {
    my ($self, $opts) = @_;

    my $key      = $opts->{key};
    my $filename = $opts->{filename};

    my $thumbnail_name = 'thumbnail.png';
    my $delete = exists $opts->{delete} && $opts->{delete} == 1 ? "Y" : "N";

    if ($delete eq 'Y') {
        return $self->do_delete($key, $filename, $thumbnail_name, %$opts);
    }
    else {
        return $self->do_upload($key, $filename, $thumbnail_name, %$opts);
    }
}

sub do_delete {
    my ($self, $key, $filename, $thumbnail_name, %opts) = @_;

    return -1 unless length $key && $key =~ /^\d+$/;

    $self->log->info("loading container $key");
    my $container = $self->file_store->get($key);

    unless ($container) {
        $self->log->error("$key not found");
        return -1;
    }

    if (defined $thumbnail_name) {
        $self->log->info("deleting $thumbnail_name from container $key");
        return $container->delete($thumbnail_name);
    }
    else {
        $self->log->info("deleting container $key");
        return $self->file_store->delete($key);
    }
}

sub do_upload {
    my ($self, $key, $filename, $thumbnail_name, %opts) = @_;

    # Retrieve the file
    $self->log->info("loading container $key");
    my $container = $self->file_store->get($key);


    unless (defined $container) {
        $self->log->error("no container $key found");
        return {error => 'no such container'};
    }

    my $file = $container->get($filename);

    unless (defined $file) {
        $self->log->error("no file $filename in container $key found");
        return {error => 'no such file'};
    }

    my ($tmpdir, $tmpfile) = $self->extract_to_tmpdir($file);

    unless (defined $tmpfile && -r $tmpfile) {
        $self->log->error(
            "failed to extract $filename from container $key to a temporary directory"
        );
        return {error => 'internal error'};
    }

    # Calculate the thumbnail
    my $max_size  = $self->thumbnail_size;
    my $cmd       = "convert -resize x${max_size} ${tmpfile}[0] $tmpdir/thumb.png";
    $self->log->debug($cmd);
    my $exit_code = system($cmd);

    unless ($exit_code == 0 && -r "$tmpdir/thumb.png") {
        $self->log->error(
            "failed to generate a thumbnail for $filename from container $key"
        );
        return {error => 'failed to create thumbail'};
    }

    # store the results
    $self->log->info("loading access container $key");
    $container = $self->access_store->get($key);

    unless (defined $container) {
        $self->log->info("$key not found");
        $self->log->info("creating a new access container $key");
        $container = $self->access_store->add($key);
    }

    unless (defined $container) {
        $self->log->error("failed to create access container for $key");
        return {error => 'failed to create thumbnail'};
    }

    $self->log->info("storing $tmpdir/thumb.png in access container $key");
    my $ret = $container->add($thumbnail_name,
        IO::File->new("$tmpdir/thumb.png"));

    unless ($ret) {
        $self->log->error(
            "failed to create a thumbail for $filename in container $key");
        return {error => 'failed to create thumbnail'};
    }

    $self->log->info("cleaning tmpdir $tmpdir");
    system("rm $tmpdir/*");
    system("rmdir $tmpdir");

    return $ret ? {ok => 1} : {error => 'failed to create thumbnail'};
}

sub extract_to_tmpdir {
    my ($self, $file) = @_;

    my $tmpdir = $self->tmpdir . '/' . Data::Uniqid::suniqid;

    $self->log->debug("creating $tmpdir");

    unless (mkdir $tmpdir) {
        return (undef, undef);
    }

    my $tmpfile = "$tmpdir/" . Data::Uniqid::suniqid;

    open(my $out, '>', $tmpfile);

    my $io = $file->fh;

    binmode($out, ':raw');

    while (defined($io) && !$io->eof) {
        my $buffer;
        my $len = $io->read($buffer, $self->buffer_size);
        syswrite($out, $buffer, $len);
    }

    $io->flush();
    $io->close();

    return ($tmpdir, $tmpfile);
}

1;

__END__

pod

=head1 NAME

LibreCat::Worker::ImageResizer - a worker for creating thumbnails

=head2 SYNOPSIS

    use LibreCat::Worker::ImageResizer;

    my $resizer = LibreCat::Worker::ImageResizer->new(
        files => {
            package => 'Simple',
            options => {
                root => '/data2/librecat/file_uploads'
            } ,
        access => {
            package => 'Simple',
            options => {
                root => '/data2/librecat/access_uploads'
            }
        });

    $resizer->work({key => $key, filename => $filename});

=head2 CONFIGURATION

=over

=item files

Required. The LibreCat::FileStore implementation to use for files

=item access

=item files

Required. The LibreCat::FileStore implementation to use for access files.

=item tmpdir

Optional. The temporary directory. Default /tmp

=item buffer_size

Optional. The buffer_size used for downloading files. Defautlt 8192.

=item thumbnail_size

Optiona. The size of the thumbnails. Default 200.

=back

=head2 SEE ALSO

L<LibreCat::Worker>

=cut
