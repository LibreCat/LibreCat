package LibreCat::FileStore::Local;

use Moo;
use namespace::clean;

with 'LibreCat::FileStore';

has path => (is => 'ro' , required => '1') ;

sub list {
    die "not implemented";
}

sub info {
    die "not implemented";
}

sub add {
    die "not implemented";
}

sub get {
    die "not implemented";
}

sub delete {
    die "not implemented";
}

1;

__END__
