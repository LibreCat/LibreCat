package LibreCat::Validator;

use Catmandu::Sane;
use Moo::Role;

with 'LibreCat::Logger', 'Catmandu::Validator';

has whitelist => (is => 'lazy');

sub _build_whitelist {
    [];
}

sub apply_whitelist {
    my ($self, $rec) = @_;
    my $whitelist = $self->whitelist;
    for my $key (keys %$rec) {
        unless (grep {$_ eq $key} @$whitelist) {
            $self->log->debug("deleting invalid key: $key");
            delete $rec->{$key};
        }
    }
    $rec;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Validator - Base role for LibreCat validators

=head1 DESCRIPTION

See L<Catmandu::Validator>.

=head1 METHODS

In addition to the methods in  L<Catmandu::Validator>, L<LibreCat::Validator> provides:

=head2 whitelist

Returns an arrayref of whitelisted property names.

=head2 apply_whitelist($rec)

Applies this validators whitelist to the given record, removing all keys not in
the whitelist.

=head1 SEE ALSO

L<Catmandu::Validator>

=cut
