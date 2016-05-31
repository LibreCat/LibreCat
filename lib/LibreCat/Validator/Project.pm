package LibreCat::Validator::Project;

use Catmandu::Sane;
use Moo;
use Catmandu::Validator::JSONSchema;
use Catmandu;
use namespace::clean;

with 'LibreCat::Validator::JSONSchema';

sub schema_validator {

    state $s = Catmandu::Validator::JSONSchema->new(

        schema => Catmandu->config->{schemas}->{project}

    );

}
1;
