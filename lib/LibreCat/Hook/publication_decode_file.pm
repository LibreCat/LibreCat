package LibreCat::Hook::publication_decode_file;

use Catmandu::Sane;
use Catmandu::Util qw(:is);
use Moo;
use JSON::MaybeXS qw();

with "Catmandu::Logger";

has json => (
    is => "ro",
    lazy => 1,
    default => sub {
        JSON::MaybeXS->new( utf8 => 0 );
    },
    init_arg => undef
);

sub fix {
    my ($self, $record) = @_;

    #nothing was sent
    $record->{file} = []
        unless defined $record->{file};

    #a single file was sent
    $record->{file} = [ $record->{file} ]
        if is_string( $record->{file} );

    #a list of files were sent. Make sure this hook does not break a correct record.file
    $record->{file} = [
        map {
            is_string( $_ ) ? $self->json()->decode( $_ ) : $_;
        } @{ $record->{file} }
    ];

    $record;
}

1;

=head1 NAME

LibreCat::Hook::publication_decode_file - fix publication.file after file upload

=head1 DESCRIPTION

The file uploader in the edit form of a publication record sends data back in

various ways:

* when one file is uploaded, then C<record.file> is a JSON string that represent a single file object

* when multiple files are uploaded, then C<record.file> is an array of JSON strings

Normally this strange situation should be fixed on a higher level,

but until then we split off this strange into L<LibreCat::Hook>,

en refer to it statically, so we can remove it later on.

=cut
