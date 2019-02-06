package LibreCat::FetchRecord::inspire;

use Catmandu::Util qw(:io);
use URI::Escape;
use Moo;

with 'LibreCat::FetchRecord';

has 'baseurl' =>
    (is => 'ro', default => sub {"https://inspirehep.net/record/"});

sub fetch {
    my ($self, $id) = @_;

    $id =~ s{^\D+}{};

    $self->log->debug("requesting $id from inspire");

    my $url = sprintf "%s%s?of=recjson", $self->baseurl, uri_escape_utf8($id);
    my $data = Catmandu->importer('getJSON', from => $url, warn => 0)->to_array;

    unless (@$data) {
        $self->log->error("failed to request $url");
        return ();
    }

    my $fixer = $self->create_fixer('inspire_mapping.fix');

    $data = $fixer->fix($data);

    return $data;
}

1;

__END__

=pod

=head1 NAME

LibreCat::FetchRecord::inspire - Create a LibreCat publication based on an Inspire id

=head1 SYNOPSIS

    use LibreCat::FetchRecord::inspire;

    my $pub = LibreCat::FetchRecord::inspire->new->fetch('1496182');

=cut
