package LibreCat::App::Catalogue::Controller::Importer;

use Catmandu::Sane;
use Catmandu::Util;
use Dancer qw(:syntax);
use Moo;

with 'Catmandu::Logger';

has id     => (is => 'ro', required => 1);
has source => (is => 'ro', default => sub {'crossref'});

sub fetch {
    my ($self) = @_;

    my $id     = $self->id;
    my $source = $self->source;

    return undef unless ($source =~ /^[a-zA-Z0-9]+$/);

    my $pkg = Catmandu::Util::require_package($source, 'LibreCat::FetchRecord');

    unless ($pkg) {
        $self->log->error("failed to load LibreCat::FetchRecord::$source");
        return undef;
    }

    $self->log->debug("Processing LibreCat::FetchRecord::$source $id");

    $pkg->new->fetch($id);
}

1;
