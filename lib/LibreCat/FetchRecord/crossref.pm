package LibreCat::FetchRecord::crossref;

use Catmandu::Util qw(:io :hash);
use URL::Encode qw(url_decode);
use Moo;

with 'LibreCat::FetchRecord';

sub fetch {
    my ($self, $id) = @_;

    # Clean up data
    $id =~ s{^\D+[:\/]}{};

    $self->log->debug("requesting $id from crossref");

    my $data = Catmandu->importer(
        'getJSON',
        from    => url_decode("http://api.crossref.org/works/$id"),
    )->first;

    unless ($data) {
        $self->log->error("failed to request http://api.crossref.org/works/$id");
        return wantarray ? () : undef;
    }

    my $fixer = $self->create_fixer('crossref_mapping.fix');

    $data = $fixer->fix($data);

    return wantarray ? ($data) : $data;
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
