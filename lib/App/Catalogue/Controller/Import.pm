package App::Catalogue::Controller::Import;

use Catmandu::Sane;
use Catmandu;
use Carp;
use Exporter qw/import/;

our @EXPORT    = qw/import_publication/;
our @EXPORT_OK = qw/arxiv inspire crossref pmc wos/;

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

sub wos {
    my $fh = shift;
    my $pub = Catmandu->importer('wos')->to_array;

    return $pub;
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
    my $pub = Catmandu->importer( 'crossref', from => "http://api.crossref.org/works/$id", )->first;

    return $pub;
}

sub pmc {
    my $id = shift;
    my $pub = Catmandu->importer( 'pmc', query => $id, )->first;

    return $pub;
}

1;
