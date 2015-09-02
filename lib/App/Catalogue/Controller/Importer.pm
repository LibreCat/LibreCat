package App::Catalogue::Controller::Importer;

use Catmandu::Sane;
use Catmandu;
use Catmandu::Util qw(:io);
use Furl;
use Hash::Merge qw(merge);
use Moo;

has id => (is => 'ro', required => 1);
has source => (is => 'ro', default => sub {'crossref'});

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
        fix => [join_path('fixes','arxiv_mapping.fix')],
        )->first;
}

sub inspire {
    my ($self, $id) = @_;

    Catmandu->importer(
        'Inspire',
        id => $id,
        fix => [join_path('fixes','inspire_mapping.fix')],
        )->first;
}

sub crossref {
    my ($self, $id) = @_;

    my $data = Catmandu->importer(
        'getJSON',
        from => "http://api.crossref.org/works/$id",
        fix => [join_path('fixes','crossref_mapping.fix')],
        )->first;

    # try @datacite if crossref has no data
    if(!$data) {
        $data = $self->datacite($id);
    }

    return $data;
}

sub datacite {
    my ($self, $id) = @_;

    my $furl = Furl->new(
        agent => "Chrome 35.1",
        timeout => 10,
        headers => [Accept => 'application/x-datacite+xml'],
        );

    my $res = $furl->get('http://data.datacite.org/'. $id);
    Catmandu->importer(
        'XML',
        file => $res->content,
        fix => [join_path('fixes','from_datacite.fix')],
        )->first;
}

sub epmc {
    my ($self, $id) = @_;

    Catmandu->importer(
        'EuropePMC',
        query => $id,
        fix => [join_path('fixes','epmc_mapping.fix')],
        )->first;
}

# Bielefeld specific, bis=bielefeld information system!
sub bis {
    my ($self, $id) = @_;

    my $furl = Furl->new( agent => "Chrome 35.1", timeout => 10 );

    my $base_url = 'http://ekvv.uni-bielefeld.de/ws/pevz';
    my $url      = $base_url . "/PersonKerndaten.xml?persId=$id";
    my $url2     = $base_url . "/PersonKontaktdaten.xml?persId=$id";

    my $res = $furl->get($url);
    my $p1 = Catmandu->importer(
        'XML',
        file => $res->content,
        fix => [join_path('fixes','pevz_mapping.fix')],
        )->first;

    $res = $furl->get($url2);
    my $p2 = Catmandu->importer(
        'XML',
        file => $res->content,
        fix => [join_path('fixes','pevz_mapping.fix')],
        )->first;

    my $merger = Hash::Merge->new();

    return $merger->merge( $p1, $p2 );
}

1;
