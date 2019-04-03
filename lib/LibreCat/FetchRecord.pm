package LibreCat::FetchRecord;

use Catmandu::Sane;
use Catmandu;
use LibreCat qw(:self);
use Moo::Role;
use namespace::clean;

with 'Catmandu::Logger';

requires 'fetch';

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

Create one publication record given an id or textual input. When called in a
list context possible more than one record can be returned.

=head1 SEE ALSO

L<LibreCat::FetchRecord::arxiv> ,
L<LibreCat::FetchRecord::bibtex> ,
L<LibreCat::FetchRecord::crossref> ,
L<LibreCat::FetchRecord::datacite> ,
L<LibreCat::FetchRecord::epmc> ,
L<LibreCat::FetchRecord::inspire> ,
L<LibreCat::FetchRecord::wos>

=cut
