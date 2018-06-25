package LibreCat::Logger;

use Catmandu::Sane;
use Log::Any ();
use Moo::Role;
use namespace::clean;

has log => (is => 'lazy');

sub _build_log {
    Log::Any->get_logger(category => ref $_[0]);
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
