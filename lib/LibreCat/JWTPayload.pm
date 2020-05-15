package LibreCat::JWTPayload;

use Catmandu::Sane;
use Catmandu;
use Moo;
use Crypt::JWT qw(encode_jwt decode_jwt);
use Catmandu::Util qw(:is);
use Try::Tiny;
use LibreCat qw();
use LibreCat::Validation::Error;
use namespace::clean;

extends "LibreCat::Validator::JSONSchema";

has secret => (
    is => 'ro',
    required => 1,
    init_arg => undef,
    default => sub {
        LibreCat->instance()->config->{json_api_v1}{token_secret};
    }
);

has bag => (
    is => "ro",
    lazy => 1,
    default => sub {
        Catmandu->store("main")->bag("jwt_payload");
    },
    init_arg => undef,
    handles => "Catmandu::Bag"
);

# overrides for LibreCat::Validator::JSONSchema - start
has '+namespace' => (
    is => "ro",
    default => sub { "validator.jsonschema.errors" },
    init_arg => undef
);

has '+schema' => (
    is => "lazy",
    init_arg => undef
);

sub _build_schema {
    my $self = $_[0];
    +{
        '$schema'   => "http://json-schema.org/draft-04/schema#",
        title       => "librecat jwt payload",
        type        => "object",
        properties  => {
            #Note: do not allow _id: jwt are self-contained, so any update in the payload table does not affect the existing jwt
            iss => {
                type => "string",
                minimum => 0
            },
            sub => {
                type => "string",
                minimum => 0
            },
            exp => {
                type => "integer",
                minimum => 0
            },
            nbf => {
                type => "integer",
                minimum => 0
            },
            model => {
                type => "string",
                minLength => 1,
                enum => LibreCat->instance()->models()
            },
            action => {
                type => "array",
                minItems => 1,
                items => {
                    type => "string",
                    enum => [qw(index create show update patch delete)]
                }
            },
            cql => {
                type => "string",
                minLength => 1
            }
        },
        required => [],
        additionalProperties => 0,
        #we need to validate cql query against a model
        if => {
            required => ["cql"]
        },
        then => {
            required => ["model"]
        }
    };

}

around validate_data => sub {

    my( $orig, $self, $payload ) = @_;

    my $errors = $orig->( $self, $payload );

    #if cql is provided, check if cql is valid for that model
    if( is_string( $payload->{model} ) && is_string( $payload->{cql} ) ){

        try {

            LibreCat
                ->instance()
                ->model( $payload->{model} )
                ->search_bag()
                ->translate_cql_query( $payload->{cql} );

        }catch{

            $errors //= [];
            push @$errors, LibreCat::Validation::Error->new(
                code      => "cql_invalid",
                i18n      => [ $self->namespace() . ".string.pattern", "cql" ],
                property  => "cql",
                field     => "cql",
                validator => ref($self)
            );

        };

    }

    $errors;

};
# overrides for LibreCat::Validator::JSONSchema - end

# overrides for Catmandu::Bag - start
around add => sub {

    my( $orig, $self, $payload ) = @_;

    #validate hash reference against schema
    return unless $self->is_valid( $payload );

    #store payload in the database
    #this way we can provoke tokens: tokens that can be decrypted but for which no payload can be found are interpreted as revoked.
    $orig->( $self, $payload );

};
# overrides for Catmandu::Bag - end

sub encode {

    my( $self, $payload ) = @_;

    encode_jwt( payload => $payload, key => $self->secret, alg => 'HS512' );

}

sub decode {

    my( $self, $token, %opts ) = @_;

    my %decode_args = ( token => $token, key => $self->secret, accepted_alg => 'HS512');

    unless( $opts{validate} ){

        $decode_args{verify_nbf} = 0;
        $decode_args{verify_exp} = 0;

    }

    my $payload;

    try {

        $payload = decode_jwt( %decode_args );
        if( $opts{validate} ){

            if( is_string( $payload->{_id} ) ){

                $payload = undef unless $self->get( $payload->{_id} );

            }
            else {

                $payload = undef;

            }

        }

    }catch {

        $self->log->errorf( "unable to decode jwt: $_" );

    };

    $payload;

}

1;

__END__

=pod

=head1 NAME

LibreCat::JWTPayload - manage json web tokens

=head1 INHERITANCE

This package inherits from package L<LibreCat::Validator::JSONSchema>,

so all of its methods are availabe. All of its constructor arguments are set

internally and cannot be overwritten.

This package also handles the methods of its bag, so methods like C<add>, C<get>, C<each>

are all available.

=head1 METHODS

=head2 secret()

* isa: string

* is: ro

* description: secret key for L<Crypt::JWT>. This secret is read from configuration key C<< json_api_v1.token_secret >>

=head2 bag()

* isa: instance of L<Catmandu::Bag>.

* is: ro

* description: internal method that loads C<< Catmandu->store("main")->bag("jwt_payload") >>. This bag stores the payload of all the generated tokens

=head2 schema

* isa: hash reference

* is: ro

* description: schema used to validate payload against schema (see below)

* schema is contained within this package and defined as follows:

    * attribute C<action>:
        * type: array of strings
        * each string is an enum: "show", "create", "update", "index" or "patch"
        * required: false
        * note: This is a custom attribute, added for the purpose of LibreCat only.

    * attribute C<model>:
        * type: string
        * enum: names of the existing models
        * required: false
        * note: This is a custom attribute, added for the purpose of LibreCat only.

    * attribute C<cql>:
        * type: string
        * required: false, unless attribute C<model> is given.
        * note: This is a custom attribute, added for the purpose of LibreCat only.

    * attribute C<exp>:
        * type: integer
        * minimum: 0
        * required: false
        * description: expiration time, expressed as number of seconds since the Epoch. More info at L<https://tools.ietf.org/html/rfc7519#section-4.1.4>.

    * attribute C<nbf>:
        * type: integer
        * minimum: 0
        * required: false
        * description: time before which the token cannot be used, expressed as number of seconds since the Epoch. More info at L<https://tools.ietf.org/html/rfc7519#section-4.1.5>

    * attribute C<iss>:
        * type: string
        * minimum length: 0
        * required: false
        * description: issuer (more info at L<https://tools.ietf.org/html/rfc7519#section-4.1.1>. This attribute is only used for administration and therefore does not add any security

    * attribute C<sub>
        * required: false
        * type: string
        * minimum length: 0
        * description: subject (more info at L<https://tools.ietf.org/html/rfc7519#section-4.1.2>. This attribute is only used for administration and therefore does not add any security

* effect of each payload attribute:

    * an empty hash means no restrictions
    * when C<model> is given, then only this model is accessable
    * when C<action> is given, then only actions in this array are accessable:
        * C<show> : access the single record route C<GET /api/v1/:model/:id>
        * C<create> : create records in route C<POST /api/v1/:model>
        * C<update> : overwrite records in route C<PUT /api/v1/:model/:id>
        * C<patch> : patch records in route C<PATCH /api/v1/:model/:id>
        * C<index> : search for records in route C<GET /api/v1/:model>
    * when C<cql> (and also C<model>), then only records from this model and filtered by cql are accessable
    * when C<exp> is given, the token can only be used before this time
    * when C<nbf> is given, the token can only be used after this time

=head2 add( $payload ) : $payload

* argument C<$payload> must be a hash reference

* argument C<$payload> is validated against schema above

* if C<$payload> contains the attribute C<cql>, then the corresponding model tests if the query is valid.

* the C<$payload> is added to the database table "jwt_payload" that adds the extra attribute C<_id> to the payload

* updated payload is returned as YAML for future reference.

* on error, C<< undef >> is returned. Errors can be read by reading C<< last_errors() >> (inherited from L<LibreCat::Validator::JSONSchema>)

Note: existing payload cannot be updated! Attributes like C<_id> are forbidden.

The reason for this is that a JWT is self contained, and any update in the payload
table does not influence that token.

=head2 get( $payload_id ) : $payload

Payload record is returned as YAML, if present.

=head2 encode( $payload_id ) : $token

* Payload record with _id $payload_id is fetched

* Payload record is encrypted into a token.

=head2 decode( $token [, validate => 0|1 ] ): $payload

* decrypts the token

* a payload is returned when:

    * the token can be decrypted

    * the token is not expired (if applicable). See payload attribute C<exp>. To disable this, set option C<validate> to C<0>.

    * the token is ready to be used (if applicable). See payload attribute C<nbf>. To disable this, set option C<validate> to C<0>.

    * the C<_id> in the payload corresponds to a record in the table "jwt". If not, the token is considered "revoked". To disable this, set option C<validate> to C<0>.

* further validation of the payload must be done by a specific application.

e.g. Route C<< GET /api/v1/publication/1 >> accepts the following payloads

    * C<< {} >>
    * C<< { "action" : ["show") } >>
    * C<< { "model" : "publication" } >>

but not

    * C<< { "action": ["update"] } >>
    * C<< { "model" : "department" } >>
    * C<< { "model" : "publication", "cql" : "id=99" } >>

=cut
