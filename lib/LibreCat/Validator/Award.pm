package LibreCat::Validator::Award;

use Catmandu::Sane;
use Moo;
use Catmandu::Validator::JSONSchema;
use Catmandu;
use namespace::clean;

with 'LibreCat::Validator::JSONSchema';

sub schema_validator {

    state $s = Catmandu::Validator::JSONSchema->new(

        schema => Catmandu->config->{schemas}->{award}

    );

}

sub white_list {
    state $properties = Catmandu->config->{schemas}->{award}->{properties} // {};
    return sort keys %$properties;
}

1;
