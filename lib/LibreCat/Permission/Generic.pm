package LibreCat::Permission::Generic;

use Catmandu::Sane;
use Moo;
use namespace::clean;

with 'LibreCat::Permission';

sub can_edit {
    my ($self, $id, $opts) = @_;

    $opts->{role} eq 'super_admin' ? return 1 : return 0;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Permission::Generic - a generic permission handler

=head1 SYNOPSIS

    package MyPackage;


=head1 SEE ALSO

L<LibreCat>, L<LibreCat::Permission>

=cut
