package LibreCat::Cmd::count;

use Catmandu::Sane;
use parent qw(Catmandu::Cmd::count);

sub description {
    return <<EOF
WARNING - Low level command

WARNING - These low level commands will skip all validation/business rules!

Usage:

librecat count <STORE> <OPTIONS>

librecat countsearch --bag publication --query 'title:Acme'

Options:
EOF
}

1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::count - manage librecat metadata store - count number of objects

=cut
