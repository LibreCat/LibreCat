package LibreCat::Hook::sleep;

use Catmandu::Sane;
use Moo;

sub fix {
    my ($self, $data) = @_;

    sleep 1;

    $data;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Hook::sleep - a LibreCat hook that sleeps for 1 second

=head1 SEE ALSO

L<LibreCat>, L<LibreCat::Hook>

=cut
