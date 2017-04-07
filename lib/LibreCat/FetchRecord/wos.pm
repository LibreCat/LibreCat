package LibreCat::FetchRecord::wos;

use Catmandu::Util qw(:io);
use Moo;
use Dancer qw(:syntax);

with 'LibreCat::FetchRecord';

sub fetch {
    my ($self, $ris) = @_;

    $self->log->debug("parsing WOS data: $ris");

    my $fixer = $self->create_fixer('wos_mapping.fix');

    my $data
        = $fixer->fix(Catmandu->importer('RIS', file => \$ris))->to_array;

    unless (@$data) {
        $self->log->error("failed to import data from $ris");
        return ();
    }

    return $data;
}

1;
