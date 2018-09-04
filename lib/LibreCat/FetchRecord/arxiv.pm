package LibreCat::FetchRecord::arxiv;

use Catmandu::Util qw(:io);
use Moo;
use Try::Tiny;
use Dancer qw(:syntax);

with 'LibreCat::FetchRecord';

has 'base_api' =>
    (is => 'ro', default => sub {"https://export.arxiv.org/api/query"});
has 'base_frontend' =>
    (is => 'ro', default => sub {"https://arxiv.org"});

sub fetch {
    my ($self, $id) = @_;

    # Clean the identifier and keep only the part with the id
    $id =~ s{\S+[:\/]}{};

    $self->log->debug("requesting $id from arXiv");

    my $data = [];

    try {
        $data = Catmandu->importer('ArXiv',
                    query         => $id,
                    base_api      => $self->base_api,
                    base_frontend => $self->base_frontend)->to_array;
    };

    unless (@$data) {
        $self->log->error("failed query ArXiv");
        return ();
    }

    my $fixer = $self->create_fixer('arxiv_mapping.fix');

    $data = $fixer->fix($data);

    return $data;
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
