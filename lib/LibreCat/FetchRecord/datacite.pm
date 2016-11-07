package LibreCat::FetchRecord::datacite;

use Catmandu::Util qw(:io :hash);
use Furl;
use Moo;

with 'LibreCat::FetchRecord';

sub fetch {
    my ($self, $id) = @_;

    $self->log->debug("requesting $id from datacite");

    my $furl = Furl->new(
        agent   => "Chrome 35.1",
        timeout => 10,
        headers => [Accept => 'application/x-datacite+xml'],
    );

    my $res = $furl->get('http://data.datacite.org/' . $id);

    my $data = Catmandu->importer(
        'XML',
        file => $res->content,
    )->first;

    my $fixer = $self->create_fixer('from_datacite.fix');

    $data = $fixer->fix($data);

    $data;
}

1;
