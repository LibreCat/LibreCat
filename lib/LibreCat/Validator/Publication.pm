package LibreCat::Validator::Publication;

use Catmandu::Sane;
use Moo;
use Catmandu::Validator::JSONSchema;
use Catmandu;
use namespace::clean;

with 'LibreCat::Validator::JSONSchema';

sub schema_validator {

    state $s = Catmandu::Validator::JSONSchema->new(

        schema => Catmandu->config->{schemas}->{publication}

    );

}

sub white_list {
    state $properties
        = Catmandu->config->{schemas}->{publication}->{properties} // {};
    return sort keys %$properties;
}

1;
