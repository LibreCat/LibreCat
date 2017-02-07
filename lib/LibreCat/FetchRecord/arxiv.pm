package LibreCat::FetchRecord::arxiv;

use Catmandu::Util qw(:io);
use Moo;
use Dancer qw(:syntax);

with 'LibreCat::FetchRecord';

sub fetch {
    my ($self, $id) = @_;

    # Clean the identifier and keep only the part with the id
    $id =~ s{\S+[:\/]}{};

    $self->log->debug("requesting $id from arXiv");

    my $data = Catmandu->importer(
        'ArXiv',
        query => $id,
    )->first;

    unless ($data) {
        $self->log->error("failed query ArXiv");
        return wantarray ? () : undef;
    }

    my $fixer = $self->create_fixer('arxiv_mapping.fix');

    $data = $fixer->fix($data);

    return wantarray ? ($data) : $data;
}

1;

__END__

=pod

=head1 NAME

LibreCat::FetchRecord::arxiv - Create a LibreCat publication based on an Arxiv id

=head1 SYNOPSIS

    use LibreCat::FetchRecord::arxiv;

    my $pub = LibreCat::FetchRecord::arxiv->new->fetch('arXiv:1609.01725');

=cut
