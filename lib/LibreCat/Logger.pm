package LibreCat::Logger;

use Catmandu::Sane;
use Log::Log4perl ();
use Moo::Role;
use namespace::clean;

has log => (is => 'lazy');

sub _build_log {
    my ($self) = @_;

    Log::Log4perl::get_logger(ref $self);
}

1;

__END__

=pod

=head1 NAME

LibreCat::Logger - Role that provides access to the LibreCat logger.

=head1 METHODS

=head2 log

    $log->debug("added $id");

=cut
