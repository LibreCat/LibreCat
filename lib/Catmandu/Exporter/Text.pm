package Catmandu::Exporter::Text;

use Catmandu::Sane;
use Catmandu::Util qw/trim/;
use Moo;
use HTML::Entities qw/decode_entities/;

extends 'Catmandu::Exporter::Cite';

around _cite => sub { # strip tags
    my ($orig, $self, $pub) = @_;
    if (my $cite = $orig->($self, $pub)) { # strip tags, decode entites and trim
        $cite =~ s!<[^>]+>!!go;
        return trim(decode_entities($cite));
    }
    return;
};

1;
