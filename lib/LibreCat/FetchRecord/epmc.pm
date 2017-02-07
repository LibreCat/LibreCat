package LibreCat::FetchRecord::epmc;

use Catmandu::Util qw(:io);
use URL::Encode qw(url_decode);
use Moo;

with 'LibreCat::FetchRecord';

sub fetch {
    my ($self, $id) = @_;

    $id =~ s/^\D+(\d+)/$1/i;

    $self->log->debug("requesting $id from epmc");

    my $url = url_decode sprintf("http://www.ebi.ac.uk/europepmc/webservices/rest/search?query=%s&format=json", $id);

    my $data = Catmandu->importer(
        'getJSON',
        from => $url
    )->first;

    unless ($data) {
        $self->log->error("failed to request $url");
        return wantarray ? () : undef;
    }

    my $fixer = $self->create_fixer('epmc_mapping.fix');

    $data = $fixer->fix($data);

    wantarray ? ($data) : $data;
}

1;

__END__

=pod

=head1 NAME

LibreCat::FetchRecord::epmc - Create a LibreCat publication based on a PubMed id

=head1 SYNOPSIS

    use LibreCat::FetchRecord::epmc;

    my $pub = LibreCat::FetchRecord::epmc->new->fetch('27740824');

=cut
