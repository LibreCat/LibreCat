package LibreCat::MimeType;

use Catmandu::Sane;
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

    my $type = 'application/octet-stream';

    my $mime =  $self->types->mimeTypeOf($ext);

    # Require explicit stringification!
    $type = sprintf "%s" , $mime->type if $mime;

    return $type;
}

1;
