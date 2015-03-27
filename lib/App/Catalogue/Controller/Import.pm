package App::Catalogue::Controller::Import;

use Catmandu::Sane;
use Catmandu;
use App::Helper;
use Carp;
use Exporter qw/import/;

our @EXPORT    = qw/import_publication/;
our @EXPORT_OK = qw/arxiv inspire crossref pmc/;

my %dispatch = (
    arxiv    => \&arxiv,
    inspire  => \&inspire,
    crossref => \&crossref,
    epmc   => \&epmc,
);

my $appdir = h->config->{appdir};

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
    Catmandu->importer(
        'ArXiv',
        query => $id,
        fix => ["$appdir/fixes/arxiv_mapping.fix"],
        )->first;
}

sub inspire {
    my $id = shift;
    Catmandu->importer(
        'Inspire',
        id => $id,
        fix => ["$appdir/fixes/inspire_mapping.fix"],
        )->first;
}

sub crossref {
    my $id = shift;
    Catmandu->importer(
        'getJSON',
        from => "http://api.crossref.org/works/$id",
        fix => ["$appdir/fixes/crossref_mapping.fix"],
        )->first;
}

sub epmc {
    my $id = shift;
    Catmandu->importer(
        'EuropePMC',
        query => $id,
        fix => ["$appdir/fixes/pmc_mapping.fix"],
        )->first;
}

1;
