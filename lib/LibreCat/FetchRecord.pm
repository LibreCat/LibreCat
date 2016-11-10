package LibreCat::FetchRecord;

use Catmandu::Sane;
use Catmandu;
use LibreCat;
use Moo::Role;
use namespace::clean;

with 'Catmandu::Logger';

requires 'fetch';

sub create_fixer {
    my ($self, $file) = @_;

    $self->log->debug("searching for fix `$file'");

    for my $p (@{LibreCat->layers->fixes_paths}) {
        $self->log->debug("testing `$p/$file'");
        if (-r "$p/$file") {
            $self->log->debug("found `$p/$file'");
            return Catmandu::Fix->new(fixes => ["$p/$file"]);
        }
    }

    $self->log->error("can't find a fixer for: `$file'");

    return Catmandu::Fix->new();
}

1;

__END__

=pod

=head1 NAME

LibreCat::FetchRecord - LibreCat record creator

=head1 SYNOPSIS

    package LibreCat::FetchRecord::bla;

    use Moo;

    with 'LibreCat::FetchRecord';

    sub fetch {
        my ($self, $id) = @_;

        # given the $id fetch/generate/create one valid publication record
        return +{
            ...
            ...
            ...
        };
    }

    1;

=head1 DESCRIPTION

Create one publication record given an id or textual input.

=head1 SEE ALSO

L<LibreCat::FetchRecord::arxiv> ,
L<LibreCat::FetchRecord::bibtex> ,
L<LibreCat::FetchRecord::crossref> ,
L<LibreCat::FetchRecord::datacite> ,
L<LibreCat::FetchRecord::epmc> ,
L<LibreCat::FetchRecord::inspire> ,
L<LibreCat::FetchRecord::wos>

=cut
