package LibreCat::FetchRecord::datacite;

use Catmandu::Util qw(:io :hash);
use Furl;
use Try::Tiny;
use Moo;

with 'LibreCat::FetchRecord';

has 'baseurl' => (is => 'ro', default => sub {"http://data.datacite.org/"});

sub fetch {
    my ($self, $id) = @_;

    # Clean up data
    $id =~ s{^\D+[:\/]}{};

    $self->log->debug("requesting $id from datacite");

    my $furl = Furl->new(
        agent   => "Chrome 35.1",
        headers => [Accept => 'application/x-datacite+xml'],
    );

    my $res = $furl->get($self->baseurl . $id);

    return undef unless $res;

    my $xml = $res->content;

    return () unless $xml;

    my $data = [];
    try {
        $data = Catmandu->importer('XML', file => \$xml,)->to_array;
    };

    unless (@$data) {
        $self->log->error("failed to parse xml : $xml");
        return ();
    }

    my $fixer = $self->create_fixer('from_datacite.fix');

    $data = $fixer->fix($data);

    return $data;
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
