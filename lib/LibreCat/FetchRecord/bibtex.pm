package LibreCat::FetchRecord::bibtex;

use Catmandu::Util qw(:io);
use Moo;

with 'LibreCat::FetchRecord';

sub fetch {
    my ($self, $bibtex) = @_;

    $self->log->debug("parsing bibtex $bibtex");

    my $data = Catmandu->importer(
        'BibTeX',
        file => \$bibtex,
    )->first;

    my $fixer = $self->create_fixer('bibtex_mapping.fix');

    $data = $fixer->fix($data);

    $data;
}

1;
