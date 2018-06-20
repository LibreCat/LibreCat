package LibreCat::FetchRecord::crossref;

use Catmandu::Util qw(:io :hash);
use URI::Escape;
use Moo;

with 'LibreCat::FetchRecord';

has 'baseurl' =>
    (is => 'ro', default => sub {"https://api.crossref.org/works/"});

sub fetch {
    my ($self, $id) = @_;

    # Clean up data
    $id =~ s{^\D+[:\/]}{};

    $self->log->debug("requesting $id from crossref");

    my $url = sprintf "%s%s", $self->baseurl, uri_escape_utf8($id);

    my $data = Catmandu->importer('getJSON', from => $url)->to_array;

    unless (@$data) {
        $self->log->error(
            "failed to request https://api.crossref.org/works/$id");
        return ();
    }

    my $fixer = $self->create_fixer('crossref_mapping.fix');

    $data = $fixer->fix($data);

    return $data;
}

1;

__END__

=pod

=head1 NAME

LibreCat::FetchRecord::crossref - Create a LibreCat publication based on a DOI

=head1 SYNOPSIS

    use LibreCat::FetchRecord::crossref;

    my $pub = LibreCat::FetchRecord::crossref->new->fetch('doi:10.1002/0470841559.ch1');

=cut
