package LibreCat::FileStore::Container::Simple;

use Moo;
use Carp;
use IO::File;
use File::Path;
use File::Copy;
use LibreCat::FileStore::File::Simple;
use Catmandu::Util;
use namespace::clean;

with 'LibreCat::FileStore::Container';

has _path => (is => 'ro');

sub list {
    my ($self) = @_;
    my $path = $self->_path;

    my @result = ();

    for my $file (glob("$path/*")) {
        $file =~ s/^.*\///;
        next if index($file,".") == 0;
        push @result , $self->get($file);
    }

    return @result;
}

sub exists {
    my ($self,$key) = @_;
    my $path = $self->_path;

    -f "$path/$key";
}

sub get {
    my ($self,$key) = @_;
    my $path = $self->_path;

    my $file = "$path/$key";

    return undef unless -f $file;

    my $data = IO::File->new($file, "r");
    my $stat = [$data->stat];

    my $size     = $stat->[7];
    my $modified = $stat->[9];
    my $created  = $stat->[10]; # no real creation time exists on Unix

    LibreCat::FileStore::File::Simple->new(
            key      => $key ,
            size     => $size ,
            md5      => '' ,
            created  => $created ,
            modified => $modified ,
            data     => $data
    );
}

sub add {
    my ($self,$key,$data) = @_;
    my $path = $self->_path;

    return undef if ($key =~ m/^\.|[\/]|\s/);

    if (Catmandu::Util::is_invocant($data)) {
        return copy($data, "$path/$key");
    }
    else {
        return Catmandu::Util::write_file("$path/$key", $data);
    }
}

sub delete {
    my ($self,$key) = @_;
    my $path = $self->_path;

    return undef if ($key =~ m/^\.|[\/]|\s/);
    return undef unless -f "$path/$key";
    unlink "$path/$key";
}

sub commit {
    return 1;
}

sub read_container {
    my ($class,$path) = @_;
    croak "Need a path" unless $path;

    my $key;
    if ($path =~ m{\/(\d{3})\/(\d{3})\/(\d{3})}) {
        $key = "$1$2$3";
        $key =~ s{^0+}{};
    }
    else {
        croak "illegal path $path";
    }

    return undef unless -d $path;

    my @stat = stat $path;

    my $inst = $class->new(key  => $key);
    $inst->{created}  = $stat[10];
    $inst->{modified} = $stat[9];
    $inst->{_path}    = $path;
    $inst;
}

sub create_container {
    my ($class,$path,$key) = @_;

    croak "Need a path and a key" unless $path && $key;

    File::Path::make_path($path);

    $class->read_container($path);
}

sub delete_container {
    my ($class,$path) = @_;

    croak "Need a path" unless $path;

    return undef unless -d $path;

    File::Path::remove_tree($path);
}

1;

__END__;

=pod

=head1 NAME

LibreCat::FileStore::Container::Simple - A default implementation of a file storage container

=head1 SYNOPSIS

    use LibreCat::FileStore::Simple;

    my $filestore = LibreCat::FileStore::Simple->new(%options);

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
