package LibreCat::FileStore::Bag::Container;

use Moo;
use File::Path;
use Catmandu::Importer::BagIt;
use Catmandu::Exporter::BagIt;
use Carp;
use namespace::clean;

with 'LibreCat::FileStore::Container';

has path => (is => 'ro', required => 1);
has info => (is => 'ro');

sub load {
    my ($self) = @_;
    my $path   = $self->path;

    $self->log->debug("Loading: $path");
    unless (-d $path) {
        $self->log->error("No such bag $path");
        return undef;
    }

    my $reader = Catmandu::Importer::BagIt->new(bags => $path);

    $self->{info} = $reader->first;

    $self->{created}  = $self->{info}->{tags}->{'Unix-Creation-Time'};
    $self->{modified} = $self->{info}->{tags}->{'Unix-Modification-Time'};
}

sub create {
    my ($class,%options) = @_;
    croak "Need a path and a key" unless exists $options{path} && exists $options{key};

    my $writer = Catmandu::Exporter::BagIt->new(overwrite => 1);

    $writer->add({
        _id  => $options{path} ,
        tags => {
            'Archive-Id'             => $options{key} ,
            'Unix-Creation-Time'     => time ,
            'Unix-Modification-Time' => time ,
        } 
    });

    my $inst = $class->new(
        path => $options{path},
        key  => $options{key} , 
    );

    $inst->load;

    $inst;
}

sub delete {
    my ($class,%options) = @_;
    croak "Need a path and a key" unless exists $options{path} && exists $options{key};

    File::Path::remove_tree($options{path});
}

1;

__END__;