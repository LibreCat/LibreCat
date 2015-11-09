package LibreCat::FileStore::Bag;

use Moo;
use Carp;
use LibreCat::FileStore::Bag::Container;
use namespace::clean;

with 'LibreCat::FileStore';

has root => (is => 'ro' , required => '1') ;

sub list {
    die "not implemented";
}

sub exists {
    my ($self,$key) = @_;

    croak "Need a key" unless defined $key;

    my $path = make_path($self->root,$key);

    -d $path;
}

sub add {
    my ($self,$key) = @_;

    croak "Need a key" unless defined $key;

    my $path = make_path($self->root,$key);

    unless ($path) {
        $self->log->error("Failed to create path from $key");
        return undef;
    }

    $self->log->debug("Generating path $path for key $key");

    LibreCat::FileStore::Bag::Container->create(path => $path, key => $key);
}

sub get {
    my ($self,$key) = @_;

    croak "Need a key" unless defined $key;

    my $path = make_path($self->root,$key);

    unless ($path) {
        $self->log->error("Failed to create path from $key");
        return undef;
    }

    $self->log->debug("Loading path $path for key $key");

    my $inst = LibreCat::FileStore::Bag::Container->new(path => $path, key => $key);

    $inst->load;

    $inst;
}

sub delete {
    my ($self,$key) = @_;

    croak "Need a key" unless defined $key;

    my $path = make_path($self->root,$key);

    unless ($path) {
        $self->log->error("Failed to create path from $key");
        return undef;
    }

    $self->log->debug("Destoying path $path for key $key");

    LibreCat::FileStore::Bag::Container->delete(path => $path, key => $key);
}

sub make_path {
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
