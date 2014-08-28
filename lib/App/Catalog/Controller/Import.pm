package App::Catalog::Controller::Import;

use Catmandu::Sane;
use Catmandu;
use Carp;
use Exporter qw/import/;

our @EXPORT    = qw/import_publication/;
our @EXPORT_OK = qw/arxiv inspire crossref pmc/;

my %dispatch = (
    arxiv    => \&arxiv,
    inspire  => \&inspire,
    crossref => \&crossref,
    pmc   => \&pmc,
);

sub import_publication {
    my ($pkg, $id) = @_;
    if ($pkg) {
        $dispatch{$pkg}->($id);
    }
    else {
        croak "No source provided";
    }
}

sub arxiv {
    my $id = shift;
    my $pub = Catmandu->importer( 'arxiv', query => $id, )->first;

    return $pub;
}

sub inspire {
    my $id = shift;
    my $pub = Catmandu->importer( 'inspire', id => $id, )->first;

    return $pub;
}

sub crossref {
    my $id = shift;
    my $pub = Catmandu->importer( 'crossref', doi => $id, )->first;

    return $pub;
}

sub pmc {
    my $id = shift;
    my $pub = Catmandu->importer( 'pmc', query => $id, )->first;

    return $pub;
}

1;
