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
