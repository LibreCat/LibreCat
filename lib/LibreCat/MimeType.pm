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

    my $mime = $self->types->mimeTypeOf($ext);

    # Require explicit stringification!
    $type = sprintf "%s", $mime->type if $mime;

    return $type;
}

=head1 NAME

LibreCat::MimeType - package that calculates mimetypes

=head1 SYNOPSIS

    my $mt = LibreCat::MimeType->new;
    $mt->content_type("test.pdf");

=cut

1;
