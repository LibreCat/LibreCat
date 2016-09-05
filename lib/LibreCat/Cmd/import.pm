package LibreCat::Cmd::import;

use Catmandu::Sane;
use parent qw(Catmandu::Cmd::import);

sub description {
    return <<EOF
WARNING - Low level command

WARNING - These low level commands will skip all validation/business rules!

Usage:

librecat import <IMPORTER> <OPTIONS> to <STORE> <OPTIONS>

librecat import YAML to search --bag publication < books.yml

Options:
EOF
}

1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::import - manage librecat metadata stores - import objects

=cut
