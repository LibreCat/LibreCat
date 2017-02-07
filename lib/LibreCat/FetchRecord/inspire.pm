package LibreCat::FetchRecord::inspire;

use Catmandu::Util qw(:io);
use Moo;

with 'LibreCat::FetchRecord';

sub fetch {
    my ($self, $id) = @_;

    $id =~ s{^\D+}{};

    $self->log->debug("requesting $id from inspire");

    my $url  = "http://inspirehep.net/record/$id?of=recjson";

    my $data = Catmandu->importer(
        'getJSON',
        from => $url
    )->first;

    unless ($data) {
        $self->log->error("failed to request $url");
        return wantarray ? () : undef;
    }

    my $fixer = $self->create_fixer('inspire_mapping.fix');

    $data = $fixer->fix($data);

    wantarray ? ($data) : $data;
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
