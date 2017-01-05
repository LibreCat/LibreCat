package LibreCat::Hook::nothing;

# Demo code that does nothing (used for testing hooks)

use Catmandu::Sane;
use LibreCat::App::Helper;
use Dancer qw(:syntax);
use Catmandu;
use Moo;

has name => (is => 'ro');
has type => (is => 'ro');

sub fix {
    my ($self, $data) = @_;

    my $name = $self->name // '??';
    my $type = $self->type // '??';

    h->log->debug("entering nothing() hook from : $name ($type)");
    h->log->debug(to_yaml $data);

    $data;
}

1;
