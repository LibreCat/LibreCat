package Catmandu::Fix::file_upload;

use Catmandu::Sane;
use Moo;
use LibreCat::App::Catalogue::Controller::File qw/handle_file/;

sub fix {
    my ($self, $data) = @_;

    LibreCat::App::Catalogue::Controller::File::handle_file($data);

    $data;
}

=head1 NAME

Catmandu::Fix::file_upload - a necessary fix to encapsulate some magic around file uploads

=head1 SYNOPSIS

file_upload()

=head1 SEE ALSO

L<Catmandu::Fix>

=cut

1;
