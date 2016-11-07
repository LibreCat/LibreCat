package LibreCat::FetchRecord::arxiv;

use Catmandu::Util qw(:io);
use Moo;
use Dancer qw(:syntax);

with 'LibreCat::FetchRecord';

sub fetch {
    my ($self, $id) = @_;

    $id =~ s/ar[Xx]iv://;
    $id =~ s/.*\///;

    $self->log->debug("requesting $id from arXiv");

    my $data = Catmandu->importer(
        'ArXiv',
        query => $id,
    )->first;

    my $fixer = $self->create_fixer('arxiv_mapping.fix');

    $data = $fixer->fix($data);

    $data;
}

1;
