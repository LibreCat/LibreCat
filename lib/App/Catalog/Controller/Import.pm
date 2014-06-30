package App::Catalog::Controller::Import;

use Catmandu::Sane;
use Catmandu;
use Carp;
use Exporter qw/import/;

our @EXPORT    = qw/import_from_id/;
our @EXPORT_OK = qw/arxiv inspire crossref plos pubmed/;

my %dispatch = (
    arxiv    => \&arxiv,
    inspire  => \&inspire,
    crossref => \&crossref,
    plos     => \&plos,
    pubmed   => \&pubmed,
);

sub _classify_id {
    my $id = shift;
    my $package;
    given ($id) {
        when (/^\d{4}\.\d{4}|^\w+\/\d+/) { $package = 'arxiv' }
        when (/^10\.\d{2,}/)             { $package = 'doi' }
        when (/^\d{1,8}$/) { $package = 'pubmed' }    # not unique!?
        default            { $package = '' }
    }

    return $package;
}

sub import_from_id {
    my $id      = shift;
    my $package = _classify_id($id);
    if ($package) {
        $dispatch{$package}->($id);
    }
    else {
        croak "Could not do anything!";
    }
}

sub arxiv {
    my $id = shift;
    my $pub = Catmandu->importer( 'arxiv', query => $id, )->first;

    return $pub;
}

sub inspire {
    my $id = shift;
    my $pub = Catmandu->importer( 'inspire', query => $id, )->first;

    return $pub;
}

sub crossref {
    my $id = shift;
    my $pub = Catmandu->importer( 'crossref', doi => $id, )->first;

    return $pub;
}

sub pubmed {
    my $id = shift;
    my $pub = Catmandu->importer( 'pubmed', term => $id, )->first;

    return $pub;
}

1;
