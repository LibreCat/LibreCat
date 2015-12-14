package LibreCat::FileStore::File;

use Moo::Role;
use IO::String;

with 'Catmandu::Logger';

has key           => (is => 'ro' , required => 1);
has content_type  => (is => 'ro');
has size          => (is => 'ro');
has md5           => (is => 'ro');
has created       => (is => 'ro');
has modified      => (is => 'ro');
has data          => (is => 'ro');

sub is_io {
    my $self = shift;
    ref($self->data) =~ /^IO/ ? 1 : 0;
}

sub fh {
    my $self = shift;
    $self->is_io ? $self->data : IO::String->new($self->data);
}

1;

__END__
