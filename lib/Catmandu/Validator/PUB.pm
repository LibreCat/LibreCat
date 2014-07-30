package Catmandu::Validator::PUB;

use Catmandu::Sane;
use Catmandu::Util qw(:is);
use Moo;

with 'Catmandu::Validator';

sub validate_data {
    my ( $self, $data ) = @_;

    my $error = [];

    #my $error = &{$self->handler}($data);
    #$error = [$error] unless !$error || ref $error eq 'ARRAY';

    # id, year
    ( $data->{_id} && is_integer $data->{_id} )
        || ( push @$error, "Invalid _id, must be integer" );

    if ( defined $data->{year} ) {
        is_integer $data->{year} || push @$error, "Invalid year.";
    }

    # integer fields
    foreach (qw/volume issue pmid inspire wos reportNumber/) {
        if ( defined $data->{$_} ) {
            ( is_integer $data->{$_} )
                || ( push @$error, "$_ must be integer." );
        }
    }

# ## boolean fields
# foreach (qw/external popularScience qualityControlled ubiFunded/) {
#     ($data->{$_} =~ /0|1/) && (push @$error, "$_ must be boolean (0 or 1).");
# }

    # doi
#     if ( $data->{doi} =~ /^http/ ) {
#     $data->{doi} =~ s/http:\/\/doi.org\///;
#     $data->{doi} =~ s/http:\/\/dx.doi.org\///;
# }

    return $error;

}

1;
