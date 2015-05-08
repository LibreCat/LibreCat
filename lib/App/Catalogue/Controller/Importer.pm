package App::Catalogue::Controller::Importer;

use Catmandu::Sane;
use Catmandu;
use Moo;
use App::Helper;

has id => (is => 'ro', required => 1);
has source => (is => 'ro', default => sub {'crossref'});

my $appdir = h->config->{appdir} // $ENV{PWD};

sub fetch {
    my ($self) = @_;
    my $s = $self->source;
    my $id = $self->id;
    $self->$s($id);
}

sub arxiv {
    my ($self, $id) = @_;
    Catmandu->importer(
        'ArXiv',
        query => $id,
        fix => ["$appdir/fixes/arxiv_mapping.fix"],
        )->first;
}

sub inspire {
    my ($self, $id) = @_;
    Catmandu->importer(
        'Inspire',
        id => $id,
        fix => ["$appdir/fixes/inspire_mapping.fix"],
        )->first;
}

sub crossref {
    my ($self, $id) = @_;
    Catmandu->importer(
        'getJSON',
        from => "http://api.crossref.org/works/$id",
        fix => ["$appdir/fixes/crossref_mapping.fix"],
        )->first;
}

sub epmc {
    my ($self, $id) = @_;
    Catmandu->importer(
        'EuropePMC',
        query => $id,
        fix => ["$appdir/fixes/pmc_mapping.fix"],
        )->first;
}

1;
