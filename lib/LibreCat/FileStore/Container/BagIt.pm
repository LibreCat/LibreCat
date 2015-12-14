package LibreCat::FileStore::Container::BagIt;

use Moo;
use Carp;
use File::Path;
use Catmandu::BagIt;
use Data::Dumper;
use namespace::clean;

with 'LibreCat::FileStore::Container';

sub list {
}

sub exists {
    # body...
}

sub get {
    # body...
}

sub add {
    # body...
}

sub delete {
    # body...
}

sub read_container {
    my ($class,$path) = @_;
    croak "Need a path" unless $path;

    my $bagit = Catmandu::BagIt->read($path);

    return undef unless $bagit;

    my $key = $bagit->get_info('Archive-Id');

    return undef unless $key;

    my $inst = $class->new(key  => $key);

    $inst->{created}  = $bagit->get_info('Unix-Creation-Time');
    $inst->{modified} = $bagit->get_info('Unix-Modification-Time');

    $inst;
}

sub create_container {
    my ($class,$path,$key) = @_;

    croak "Need a path and a key" unless $path && $key;

    my $bagit = Catmandu::BagIt->new();

    $bagit->add_info('Archive-Id' => $key);
    $bagit->add_info('Unix-Creation-Time' => time);
    $bagit->add_info('Unix-Modification-Time' => time);

    $bagit->write($path , overwrite => 1);

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