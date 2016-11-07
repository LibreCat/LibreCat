package LibreCat::FetchRecord::wos;

use Catmandu::Util qw(:io);
use Moo;
use Dancer qw(:syntax);

with 'LibreCat::FetchRecord';

sub fetch {
    my ($self, $ris) = @_;

    $self->log->debug("parsing WOS data: $ris");

    my $data = Catmandu->importer(
         'RIS',
         file => \$ris,
    )->first;

    my $fixer = $self->create_fixer('wos_mapping.fix');

    $data = $fixer->fix($data);

    $data;
}

1;
