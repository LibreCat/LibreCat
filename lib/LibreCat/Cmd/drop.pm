package LibreCat::Cmd::drop;

use Catmandu::Sane;
use parent qw(Catmandu::Cmd::drop);

sub description {
    return <<EOF
WARNING - Low level command

WARNING - These low level commands will skip all validation/business rules!

Usage:

librecat drop <STORE> <OPTIONS>

librecat drop search --bag publication

Options:
EOF
}

1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::drop - manage librecat metadata store - drop objects

=cut
