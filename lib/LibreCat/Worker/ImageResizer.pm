package LibreCat::Worker::ImageResizer;

use Moo;
use Catmandu::Util;
use Data::Uniqid;
use File::Spec;
use namespace::clean;

with 'LibreCat::Worker';

has files          => (is => 'ro' , required => 1);
has access         => (is => 'ro' , requires => 1);
has tmpdir         => (is => 'ro' , default => sub { '/tmp' });
has buffer_size    => (is => 'ro' , default => sub { 8192 });
has thumbnail_size => (is => 'ro' , default => sub { 200 });
has file_store     => (is => 'lazy');
has access_store   => (is => 'lazy');

sub _build_file_store {
    my ($self) = @_;

    my $file_store = $self->files->{package};
    my $file_opts  = $self->files->{options} // {};

    my $pkg = Catmandu::Util::require_package($file_store,'LibreCat::FileStore');
    $pkg->new(%$file_opts);
}

sub _build_access_store {
    my ($self) = @_;

    my $file_store = $self->access->{package};
    my $file_opts  = $self->access->{options} // {};

    my $pkg = Catmandu::Util::require_package($file_store,'LibreCat::FileStore');
    $pkg->new(%$file_opts);
}

sub do_work {
    my ($self,$key,$filename) = @_;

    # Retrieve the file
    $self->log->info("loading container $key");
    my $container = $self->file_store->get($key);

    unless (defined $container) {
        $self->log->error("no container $key found");
        return { error => 'no such container' };
    }

    my $file = $container->get($filename);

    unless (defined $file) {
        $self->log->error("no file $filename in container $key found");
        return { error => 'no such file' };
    }

    my ($tmpdir,$tmpfile) = $self->extract_to_tmpdir($file);

    unless (defined $tmpfile && -r $tmpfile) {
        $self->log->error("failed to extract $filename from container $key to a temporary directory");
        return { error => 'internal error' };
    }

    # Calculate the thumbnail
    my $max_size  = $self->thumbnail_size;
    my $exit_code = system "convert -resize x${max_size} ${tmpfile}[0] $tmpdir/thumb.png";

    unless ($exit_code == 0 && -r "$tmpdir/thumb.png") {
        $self->log->error("failed to generate a thumbnail for $filename from container $key");
        return { error => 'failed to create thumbail'} ;
    }

    # store the results
    $self->log->info("loading access container $key");
    $container = $self->access_store->get($key);

    unless (defined $container) {
        $self->log->info("$key not found");
        $self->log->info("creating a new access container $key");
        $container = $self->access_store->add($key);
    }

    $self->log->info("storing ${filename}.thumb.png in access container $key");
    $container->add("${filename}.thumb.png", IO::File->new("$tmpdir/thumb.png"));
    
    $self->log->info("cleaning tmpdir $tmpdir");
    system("rm $tmpdir/*");
    system("rmdir $tmpdir");

    return { ok => 1 };
}

sub extract_to_tmpdir {
    my ($self,$file) = @_;

    my $tmpdir = $self->tmpdir . '/' . Data::Uniqid::suniqid;

    unless (mkdir $tmpdir) {
        return (undef,undef);
    }

    my $tmpfile = "$tmpdir/" . Data::Uniqid::suniqid;

    open(my $out, '>:raw' , $tmpfile);

    my $io = $file->fh;

    while (! $io->eof) {
        my $buffer;
        my $len = $io->read($buffer, $self->buffer_size);
        syswrite($out, $buffer, $len);
    }

    return ($tmpdir,$tmpfile);
}


1;

__END__

pod

=head1 NAME

LibreCat::Worker::ImageResizer - a worker for creating thumbnails

=head2 SYNOPSIS

    use LibreCat::Worker::ImageResizer;

    my $resizer = LibreCat::Worker::FileUploader->new(
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

    $resizer->do_work($key,$filename);

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