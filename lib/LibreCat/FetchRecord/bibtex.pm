package LibreCat::FetchRecord::bibtex;

use Catmandu::Util qw(:io);
use Moo;

with 'LibreCat::FetchRecord';

sub fetch {
    my ($self, $bibtex) = @_;

    $self->log->debug("parsing bibtex $bibtex");

    my $fixer = $self->create_fixer('bibtex_mapping.fix');

    my $data = Catmandu->importer('BibTeX', file => \$bibtex)->to_array;

    unless (@$data) {
        $self->log->error("failed to import bibtex from $bibtex");
        return ();
    }

    $data = $fixer->fix($data);

    return $data;
}

1;

__END__

=pod

=head1 NAME

LibreCat::FetchRecord::bibtex - Create a LibreCat publication based on BibTex input

=head1 SYNOPSIS

    use LibreCat::FetchRecord::bibtex;

    my $pub = LibreCat::FetchRecord::bibtex->new->fetch(<<EOF);
    @book{book,
      author    = {Peter Babington},
      title     = {The title of the work},
      publisher = {The name of the publisher},
      year      = 1993,
      volume    = 4,
      series    = 10,
      address   = {The address},
      edition   = 3,
      month     = 7,
      note      = {An optional note},
      isbn      = {3257227892}
    }
    EOF

=cut
