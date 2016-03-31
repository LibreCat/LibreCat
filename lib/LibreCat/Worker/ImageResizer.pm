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
    my $container = $self->file_store->get($key);

    return { error => 'no such container' } unless defined $container;

    my $file = $container->get($filename);

    return { error => 'no such file' } unless defined $file;

    my ($tmpdir,$tmpfile) = $self->extract_to_tmpdir($file);

    return { error => 'internal error' } unless defined $tmpfile && -r $tmpfile;

    # Calculate the thumbnail
    my $max_size  = $self->thumbnail_size;
    my $exit_code = system "convert -resize x${max_size} ${tmpfile}[0] $tmpdir/thumb.png";

    return { error => 'failed to create thumbail'} unless $exit_code == 0 && -r "$tmpdir/thumb.png";

    # store the results
    $container = $self->access_store->get($key);

    unless (defined $container) {
        $container = $self->access_store->add($key);
    }

    $container->add("${filename}.thumb.png", IO::File->new("$tmpdir/thumb.png"));
    
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
