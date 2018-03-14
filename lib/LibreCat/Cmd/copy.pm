package LibreCat::Cmd::copy;

use Catmandu::Sane;
use parent qw(Catmandu::Cmd::copy);

sub description {
    return <<EOF;
WARNING - Low level command

WARNING - These low level commands will skip all validation/business rules!

Usage:

librecat copy <STORE> <OPTIONS> to <STORE> <OPTIONS>

librecat copy search --bag publication to \
                ElasticSearch --index_name tests --bag book

Options:
EOF
}

1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::copy - manage librecat metadata store - copy to another store

=cut
