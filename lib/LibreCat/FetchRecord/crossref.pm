package LibreCat::FetchRecord::crossref;

use Catmandu::Util qw(:io :hash);
use URL::Encode qw(url_decode);
use Moo;

with 'LibreCat::FetchRecord';

sub fetch {
    my ($self, $id) = @_;

    $id =~ s{^doi:}{}i;

    $self->log->debug("requesting $id from crossref");

    my $data = Catmandu->importer(
        'getJSON',
        from    => url_decode("http://api.crossref.org/works/$id"),
        timeout => 10,
    )->first;

    my $fixer = $self->create_fixer('crossref_mapping.fix');

    $data = $fixer->fix($data);

    # try @datacite if crossref has no data
    if (!$data or lc $data->{doi} ne lc $id) {
        $data = $self->datacite($id);
    }

    return $data;
}

1;
