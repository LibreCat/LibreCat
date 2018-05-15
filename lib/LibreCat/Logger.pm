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
