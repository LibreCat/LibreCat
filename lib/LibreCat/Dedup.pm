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

=head1 SYNOPSIS

    package LibreCat::Dedup::Foo;

    use Moo;

    with 'LibreCat::Dedup';

    sub _find_duplicate {
        my ($self, $data) = @_;

        # deduplication logic...
    }

    1;

=head1 SEE ALSO

L<LibreCat::Dedup::Publication>

=cut
