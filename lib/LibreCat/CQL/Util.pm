package LibreCat::CQL::Util;

use Catmandu::Sane;
use Catmandu::Util qw(:is);
use Exporter qw(import);
use constant CQL_RESERVED_CHARS => ('"',' ','\t','=','<','>','/','(',')');

our @EXPORT_OK = qw(cql_escape);
our %EXPORT_TAGS = (
    all => [@EXPORT_OK],
    escape => ["cql_escape"],
);

# Happily stolen from https://github.com/indexdata/cql-java/blob/18e4112ce68cdeade7d42879871d8adacd969239/src/main/java/org/z3950/zing/cql/CQLTermNode.java#L217
sub cql_escape {

    my $str = $_[0];

    return $str unless is_string( $str );

    for my $reserved_char( CQL_RESERVED_CHARS ){

        if( index( $str, $reserved_char ) >= 0 ){

            $str =~ s/"/\\"/go;
            return "\"$str\"";

        }

    }

    $str;

}

=head1 NAME

LibreCat::CQL::Util

=head1 SYNOPSIS

    use LibreCat::CQL::Util qw(cql_escape);

    # 'my weird identifier' => '"my weird identifier"'
    my $cql_query = "id=".cql_escape("my weird identifier");

=head1 DESCRIPTION

Collection of utility methods for CQL manipulation

=head1 METHODS

=head2 cql_escape( $str )

If string given contains any of reserved characters,

then all double quotes are prepended with a backslash character,

and the result is surrounded with double quotes.

=cut

1;
