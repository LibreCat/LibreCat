package LibreCat::FetchRecord::epmc;

use Catmandu::Util qw(:io);
use Moo;
use Dancer qw(:syntax);

with 'LibreCat::FetchRecord';

sub fetch {
    my ($self, $id) = @_;

    $id =~ s/^pmid.*?(\d+)/$1/i;

    $self->log->debug("requesting $id from epmc");

    my $data = Catmandu->importer(
        'EuropePMC',
        query => $id,
        fix   => [join_path('fixes', 'epmc_mapping.fix')],
    )->first;

    my $fixer = $self->create_fixer('epmc_mapping.fix');

    $data = $fixer->fix($data);

    $data;
}

1;
