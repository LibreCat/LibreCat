package LibreCat::FileStore::BagIt;

use Moo;
use Carp;
use LibreCat::FileStore::Container::BagIt;
use namespace::clean;

with 'LibreCat::FileStore';

has root => (is => 'ro' , required => '1') ;

sub list {
    my ($self,$callback) = @_;
    my $root = $self->root;
    local (*FIND);
    open (FIND,"find $root -maxdepth 5 -name data -type d|");
    while(<FIND>) {
        s/\/data$//;
        s/$root//;
        s/\///g;
        s/^0+//;
        
        if ($callback) {
            $callback->($_) || last;
        }
    }
    close (FIND);
}

sub exists {
    my ($self,$key) = @_;

    croak "Need a key" unless defined $key;

    my $path = path_string($self->root,$key);

    -d $path;
}

sub add {
    my ($self,$key) = @_;

    croak "Need a key" unless defined $key;

    my $path = path_string($self->root,$key);

    unless ($path) {
        $self->log->error("Failed to create path from $key");
        return undef;
    }

    $self->log->debug("Generating path $path for key $key");

    LibreCat::FileStore::Container::BagIt->create_container($path,$key);
}

sub get {
    my ($self,$key) = @_;

    croak "Need a key" unless defined $key;

    my $path = path_string($self->root,$key);

    unless ($path) {
        $self->log->error("Failed to create path from $key");
        return undef;
    }

    $self->log->debug("Loading path $path for key $key");

    LibreCat::FileStore::Container::BagIt->read_container($path);
}

sub delete {
    my ($self,$key) = @_;

    croak "Need a key" unless defined $key;

    my $path = path_string($self->root,$key);

    unless ($path) {
        $self->log->error("Failed to create path from $key");
        return undef;
    }

    $self->log->debug("Destoying path $path for key $key");

    LibreCat::FileStore::Container::BagIt->delete_container($path);
}

sub path_string {
    my ($root,$key) = @_;

    unless ($key =~ /^\d{1,12}$/) {
        return undef;
    }

    my $long_key = sprintf "%-12.12d", $key;
    my $path = $root . "/" . join("/",unpack('(A3)*',$long_key));

    $path;
}

1;

__END__
