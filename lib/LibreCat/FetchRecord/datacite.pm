package LibreCat::FetchRecord::datacite;

use Catmandu::Util qw(:io :hash);
use Furl;
use Moo;

with 'LibreCat::FetchRecord';

sub fetch {
    my ($self, $id) = @_;

    # Clean up data
    $id =~ s{^\D+[:\/]}{};

    $self->log->debug("requesting $id from datacite");

    my $furl = Furl->new(
        agent   => "Chrome 35.1",
        headers => [Accept => 'application/x-datacite+xml'],
    );

    my $res = $furl->get('http://data.datacite.org/' . $id);

    return undef unless $res;

    my $xml = $res->content;

    return undef unless $xml;

    my $data = Catmandu->importer(
        'XML',
        file => \$xml,
    )->first;

    my $fixer = $self->create_fixer('from_datacite.fix');

    $data = $fixer->fix($data);

    $data;
}

1;

__END__

=pod

=head1 NAME

LibreCat::FetchRecord::datacite - Create a LibreCat publication based on a DataCite id

=head1 SYNOPSIS

    use LibreCat::FetchRecord::datacite;

    my $pub = LibreCat::FetchRecord::datacite->new->fetch('10.6084/M9.FIGSHARE.94301.V1');

=cut
