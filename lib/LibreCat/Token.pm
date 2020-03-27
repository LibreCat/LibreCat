package LibreCat::Token;

use Catmandu::Sane;
use Catmandu;
use Moo;
use Crypt::JWT ':all';
use Catmandu::Util qw(:is :check require_package);
use Try::Tiny;
use namespace::clean;

with 'LibreCat::Logger';

has secret => (is => 'ro', required => 1);

has librecat => (
    is => "ro",
    isa => sub {
        check_instance($_[0],"LibreCat");
    },
    required => 1
);

has bag => (
    is => "ro",
    lazy => 1,
    default => sub {
        Catmandu->store("main")->bag("jwt");
    },
    init_arg => undef
);

has validator => (
    is => "lazy",
    lazy => 1,
    init_arg => undef
);

sub _build_validator {
    my $self = $_[0];

    require_package("LibreCat::Validator::JSONSchema")->new(
        namespace => "validator.jsonschema.errors",
        schema    => +{
            '$schema'   => "http://json-schema.org/draft-04/schema#",
            title       => "librecat audit record",
            type        => "object",
            properties  => {
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
                    enum => $self->librecat->models()
                },
                action => {
                    type => "array",
                    minItems => 1,
                    items => {
                        type => "string",
                        enum => [qw(create show update patch delete)]
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
        }
    );

}

sub encode {
    my ($self, $payload) = @_;

    #input must be hash reference
    unless( is_hash_ref( $payload ) ){

        return wantarray ?
            (undef, "payload must be hash reference") :
            undef;

    }

    #validate hash reference against schema
    my $is_valid = $self->validator()->is_valid( $payload );
    my @errors;

    unless( $is_valid ){

        return wantarray ?
            (undef, map { $_->localize("en"); } @{ $self->validator()->last_errors() }) :
            undef;

    }

    #if cql is provided, check if cql is valid for that model
    if( is_string( $payload->{cql} ) ){

        try {

            $self->librecat->model( $payload->{model} )->search_bag()->translate_cql_query( $payload->{cql} );

        }catch{

            push @errors, "unable to parse cql query '$payload->{cql}' for model '$payload->{model}'";

        };

        if( scalar( @errors ) ){

            return wantarray ?
                (undef, @errors) :
                undef;

        }

    }

    #store payload in the database
    #this way we can provoke tokens: tokens that can be decrypted but for which no payload can be found are interpreted as revoked.
    $payload = $self->bag()->add( $payload );

    my $token = encode_jwt(payload => $payload, key => $self->secret, alg => 'HS512');
    if ($self->log->is_debug) {
        $self->log->debugf("Encoded JWT token $token %s", $payload);
    }

    wantarray ? ($token) : $token;

}

sub decode {
    my ($self, $token) = @_;
    if ($self->log->is_debug && !defined $token) {
        $self->log->debug("JWT token missing");
        return;
    }

    my $payload;

    try {
        $payload = decode_jwt(token => $token, key => $self->secret, accepted_alg => 'HS512');
        if ($self->log->is_debug) {
            $self->log->debugf("Decoded JWT token $token %s", $payload);
        }
    } catch {
        if ($self->log->is_debug) {
            $self->log->debug("Invalid JWT token $token");
        }
    };

    return unless $payload;

    #refuse revoked tokens
    return unless is_string( $payload->{_id} );
    return unless $self->bag()->get( $payload->{_id} );

    $payload;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Token - manage json web tokens

=head1 CONSTRUCTOR ARGUMENTS

=head2 librecat

* required: true

* isa: instance of L<LibreCat>

* is: ro

* description: supply C<< LibreCat->instance() >>

=head2 secret

* required: true

* isa: string

* is: ro

* description: secret key for L<Crypt::JWT>

=head1 METHODS

=head2 librecat()

* isa: instance of L<LibreCat>

* is: ro

=head2 secret()

* isa: string

* is: ro

* description: secret key for L<Crypt::JWT>

=head2 bag()

* isa: instance of L<Catmandu::Bag>.

* is: ro

* description: internal method that loads C<< Catmandu->store("main")->bag("jwt") >>. This bag stores the payload of all the generated tokens

=head2 validator()

* isa: instance of L<LibreCat::Validator::JSONSchema>

* is: ro

* description: used to validate payload against schema (see below)

* schema is contained within this package and defined as follows:

    * attribute C<action>:
        * type: array of strings
        * each string is an enum: "show", "create", "update" or "patch"
        * required: false

    * attribute C<model>:
        * type: string
        * enum: names of the existing models
        * required: false

    * attribute C<cql>:
        * type: string
        * required: false, unless attribute C<model> is given.

    * attribute C<exp>:
        * type: integer
        * minimum: 0
        * required: false
        * description: expiration time, expressed as number of seconds since the Epoch.

    * attribute C<nbf>:
        * type: integer
        * minimum: 0
        * required: false
        * description: time before which the token cannot be used, expressed as number of seconds since the Epoch.

* effect of each payload attribute:

    * an empty hash means no restrictions
    * when C<model> is given, then only this model is accessable
    * when C<action> is given, then only actions in this array are accessable
    * when C<cql> (and also C<model>), then only records from this model and filtered by cql are accessable
    * when C<exp> is given, the token can only be used before this time
    * when C<nbf> is given, the token can only be used after this time

=head2 encode( $payload ) : $token, @errors

* argument C<$payload> must be a hash reference

* argument C<$payload> is validated against schema above

* if C<$payload> contains the attribute C<cql>, then the corresponding model tests if the query is valid.

* the C<$payload> is added to the database table "jwt" that adds the extra attribute C<_id> to the payload

* the C<$payload> is encrypted into a token

* return value: C<$token> and a list of possible C<@errors>. Token can be C<undef> in which case the C<@errors> must be checked.
  Note: in scalar context only the C<$token> is returned.

=head2 decode( $token ): $payload

* decrypts the token

* a payload is returned when:

    * the token can be decrypted

    * the token is not expired (if applicable). See payload attribute C<exp>.

    * the token is ready to be used (if applicable). See payload attribute C<nbf>

    * the C<_id> in the payload corresponds to a record in the table "jwt". If not, the token is considered "revoked".

* further validation of the payload must be done by a specific application.

e.g. Route C<< GET /api/v1/publication/1 >> accepts the following payloads

    * C<< {} >>
    * C<< { "action" : "show" } >>
    * C<< { "model" : "publication" } >>

but not

    * C<< { "action": "update" } >>
    * C<< { "model" : "department" } >>
    * C<< { "model" : "publication", "cql" : "id=99" } >>

=cut
