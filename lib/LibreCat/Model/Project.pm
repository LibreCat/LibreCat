package LibreCat::Model::Project;

use Catmandu::Sane;
use Moo;
use namespace::clean;

with 'LibreCat::Model';

1;

__END__

=pod

=head1 NAME

LibreCat::Model::Project - a project model

=head1 SYNOPSIS

    package MyPackage;

    use LibreCat qw(project);

    my $rec = project->get(123);

    if (project->add($rec)) {
        print "OK!";
    }

    project->delete(123);

=head1 SEE ALSO

L<LibreCat>, L<LibreCat::Model>

=cut
