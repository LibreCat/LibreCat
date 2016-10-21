package LibreCat::Hook::nothing;

# Demo code that does nothing (used for testing hooks)

use Catmandu::Sane;
use LibreCat::App::Helper;
use Dancer qw(:syntax);
use Catmandu;
use Moo;

sub fix {
    my ($self, $data) = @_;

    h->log->debug("entering nothing() hook");
    h->log->debug(to_yaml $data);
    
    $data;
}

1;
