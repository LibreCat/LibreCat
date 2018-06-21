package LibreCat::Model::Department;

use Catmandu::Sane;
use Moo;
use namespace::clean;

with 'LibreCat::Model';

1;

__END__

=pod

=head1 NAME

LibreCat::Model::Deparment - a department model

=head1 SYNOPSIS

    package MyPackage;

    use LibreCat qw(department);

    my $rec = department->get(123);

    if (department->add($rec)) {
        print "OK!"
    }

    department->delete(123);

=head1 SEE ALSO

L<LibreCat>, L<LibreCat::Model>

=cut
