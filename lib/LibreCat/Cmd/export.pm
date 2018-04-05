package LibreCat::Cmd::export;

use Catmandu::Sane;
use parent qw(Catmandu::Cmd::export);

sub description {
    return <<EOF;
WARNING - Low level command

WARNING - These low level commands will skip all validation/business rules!

Usage:

librecat export <STORE> <OPTIONS> to <EXPORTER> <OPTIONS>

librecat export search --bag publication to YAML

Options:
EOF
}

1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::export - manage librecat metadata store - export objects

=cut
