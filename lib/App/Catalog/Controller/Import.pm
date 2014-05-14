package App::Catalog::Controller::Import;

use Catmandu::Sane;
use Catmandu;

use Exporter qw/import/;

our @EXPORT    = qw/import_from_id/;
our @EXPORT_OK = qw/arxiv inspire crossref plos pubmed/;

#TODO: look at the Catmandu::Importer, update them...

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
        return {};
    }
}

sub arxiv {
	my $id  = shift;
    my $pub = Catmandu::Importer::ArXiv->new(
        query  => $id,
        fixes => ["arxiv_mapping()"],
    )->first;
    
    return $pub;
}

sub inspire {
    my $id  = shift;
    my $pub = Catmandu::Importer::Inspire->new(
        query => $id,
        fixes => ["inspire_mapping()"],
    )->first;

    return $pub;
}

sub crossref {
    my $id  = shift;
    my $pub = Catmandu::Importer::CrossRef->new(
        query => $id,
        fixes => ["crossref_mapping()"],
    )->first;

    return $pub;
}

sub plos {
    my $id  = shift;
    my $pub = Catmandu::Importer::PLoS->new(
        query => $id,
        fixes => ["plos_mapping()"],
    )->first;

    return $pub;
}

sub pubmed {
    my $id  = shift;
    my $pub = Catmandu::Importer::PubMed->new(
        term  => $id,
        fixes => ["arxiv_mapping()"],
    )->first;

    return $pub;
}

1;
