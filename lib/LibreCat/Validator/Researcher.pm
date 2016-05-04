package LibreCat::Validator::Researcher;

use Catmandu::Sane; 
use Moo;
use Catmandu::Validator::JSONSchema;
use Catmandu;
use namespace::clean;

with 'Catmandu::Validator';

sub _schema_validator {

    state $s = Catmandu::Validator::JSONSchema->new(

        schema => Catmandu->config->{schemas}->{researcher}

    );

}

sub validate_data {
    my ($self,$data) = @_;

    _schema_validator->validate($data);

    my $errors = _schema_validator->last_errors();

    return unless defined $errors;

    [ map { $_->{property}.": ".$_->{message} } @$errors ];
}

1;
