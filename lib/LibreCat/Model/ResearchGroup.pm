package LibreCat::Model::ResearchGroup;

use Catmandu::Sane;
use Moo;
use namespace::clean;

with 'LibreCat::Model';

1;

__END__

=pod

=head1 NAME

LibreCat::Model::ResearchGroup - a research group model

=head1 SYNOPSIS

    package MyPackage;

    use LibreCat qw(research_group);

    my $rec = research_group->get(123);

    if (research_group->add($rec)) {
        print "OK!";
    }

    research_group->delete(123);

=head1 SEE ALSO

L<LibreCat>, L<LibreCat::Model>

=cut
