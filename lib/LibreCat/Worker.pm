=head1 NAME

LibreCat::Worker - a base class for workers

=head1 SYNOPSIS

    package MyWorker;

    use Moo;
    with 'LibreCat::Worker';

    sub do_work {
        say "I'm working";
    }

=head1 DESCRIPTION

This is a Moo::Role for all worker packages. Required is a method that
implements the C<do_work> method.

=cut

package LibreCat::Worker;

use namespace::clean;
use Catmandu::Sane;
use Moo::Role;

with 'Catmandu::Logger';

requires 'do_work';

1;
