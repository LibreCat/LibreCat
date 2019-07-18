package LibreCat::Dedup;

use Catmandu::Sane;
use Moo::Role;
use namespace::clean;

with 'Catmandu::Logger';

requires '_find_duplicate';

sub has_duplicate {
    my ($self, $data) = @_;

    my $dup = $self->find_duplicate($data);

    if ($dup && $dup->[0]) {
        return 1;
    }
    else {
        return 0;
    }
}

sub find_duplicate {
    my ($self, $data) = @_;

    $self->_find_duplicate($data);
}

1;

__END__

=pod

=head1 NAME

LibreCat::Dedup - a LibreCat deduplication role

=cut
