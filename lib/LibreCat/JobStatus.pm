package LibreCat::JobStatus;

use Catmandu::Sane;
use namespace::clean;

sub new {
    bless $_[1];
}

sub queued {
    # known && not running
    $_[0]->[0] && !$_[0]->[1];
}

sub running {
    # known && running
    $_[0]->[0] && $_[0]->[1];
}

sub done {
    # not known
    !$_[0]->[0];
}

sub progress {
    return $_[0]->[2], $_[0]->[3];
}

1;
