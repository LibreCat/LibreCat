package LibreCat::MimeType;

use Castmandu::Sane;
use Moo;
use MIME::Types;
use namespace::clean;

has 'types' => (is => 'lazy');

sub _build_types {
    MIME::Types->new(only_complete => 1);
}

sub content_type {
    my ($self, $filename) = @_;

    return undef unless $filename;

    my ($ext) = $filename =~ /\.(.+?)$/;

    return $self->types->mimeTypeOf($ext) // 'application/octet-stream';
}

1;
