package LibreCat::Cmd::delete;

use Catmandu::Sane;
use parent qw(Catmandu::Cmd::delete);

sub description {
    return <<EOF
WARNING - Low level command

WARNING - These low level commands will skip all validation/business rules!

Usage:

librecat delete <STORE> <OPTIONS>

librecat delete search --bag publication --id 1234 --id 2345
librecat delete search --bag publication --query 'title:"My Rabbit"'
librecat delete search --bag publication

Options:
EOF
}

1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::delete - manage librecat metadata store - delete objects

=cut
