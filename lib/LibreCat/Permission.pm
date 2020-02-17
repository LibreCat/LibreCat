package LibreCat::Permission;

use Catmandu::Sane;
use LibreCat -self;
use Moo;
use namespace::clean;

with 'Catmandu::Logger';

has model => (is => 'lazy');

sub BUILD {
    my ($self) = @_;

    unless (librecat->has_model($self->model)) {
        die "Model " . $self->model . "not supported.";
    }
}

1;

__END__

=pod

=head1 NAME

LibreCat::Permission - LibreCat permission role

=cut
