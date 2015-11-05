package LibreCat::FileStore;

use Catmandu::Sane;
use Moo::Role;
use namespace::clean;

with 'Catmandu::Logger';
#with 'Catmandu::Iterable';

requires 'list';
requires 'info';
requires 'add';
requires 'get';
requires 'delete';

1;

__END__

=pod

=head1 NAME

LibreCat::FileStore - A role for implementing file storage classes

=head1 SYNOPSIS

    my $store = LibreCat::FileStore->new();

    $store->file();        # list all file containers
    $store->file('1234');  # list all files for container '1234'
    $store->info('1234');  # retrieve information on container '1234'
    $store->info('1234', file => 'cover.jpg') # retrieve information on 'cover.jpg' in container '1234'
    $store->add('1234', file => '/tmp/data.txt' , as => 'data.txt') # add a new file to a container
    $store->get('1234', file => 'data.txt') # an URL reference to 'data.txt'
    $store->delete('1234') # delete all files in container '1234'
    $store->delete('1234', file => 'data.txt') # delete file 'data.txt'

=cut
