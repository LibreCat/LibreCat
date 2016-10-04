package LibreCat::Validator::Department;

use Catmandu::Sane;
use Moo;
use Catmandu::Validator::JSONSchema;
use Catmandu;
use namespace::clean;

with 'LibreCat::Validator::JSONSchema';

sub schema_validator {

    state $s = Catmandu::Validator::JSONSchema->new(

        schema => Catmandu->config->{schemas}->{department}

    );

}

sub white_list {
    state $properties
        = Catmandu->config->{schemas}->{department}->{properties} // {};
    return sort keys %$properties;
}

1;
