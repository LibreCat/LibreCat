package LibreCat::Cmd::jwt_payload;

use Catmandu::Sane;
use Catmandu::Util qw(is_string check_hash_ref is_hash_ref);
use JSON::MaybeXS qw(decode_json);
use Carp;
use Try::Tiny;
use LibreCat::JWTPayload;
use Catmandu::Exporter::YAML;
use Catmandu::Importer::YAML;
use parent qw(LibreCat::Cmd);

sub description {
    return <<EOF;
Usage:

librecat jwt_payload add \$yaml_file_with_payloads
librecat jwt_payload get \$payload_id
librecat jwt_payload export
librecat jwt_payload decode \$token
librecat jwt_payload encode \$payload_id

EOF
}

sub command_opt_spec {
    my ($class) = @_;
    ();
}

sub command {
    my ($self, $opts, $args) = @_;

    my $commands = qr/(add|get|decode|encode|export)/;

    unless (@$args) {
        $self->usage_error("should be one of $commands");
    }

    my $cmd = shift @$args;

    unless ($cmd =~ /^$commands$/) {
        $self->usage_error("should be one of $commands");
    }

    if ($cmd eq 'add') {
        return $self->_add(@$args);
    }
    elsif( $cmd eq 'get' ){
        return $self->_get(@$args);
    }
    elsif( $cmd eq 'export' ){
        return $self->_export(@$args);
    }
    elsif( $cmd eq 'decode' ){
        return $self->_decode(@$args);
    }
    elsif( $cmd eq 'encode' ){
        return $self->_encode(@$args);
    }

}

sub to_yaml {

    my $ref = $_[0];

    my $exporter = Catmandu::Exporter::YAML->new();
    $exporter->add( $ref );
    $exporter->commit();

}

sub _add {
    my ($self, $file) = @_;

    my $importer = Catmandu::Importer::YAML->new(
        file => $file
    );

    my $exporter = Catmandu::Exporter::YAML->new();

    my $jwt_payloads = LibreCat::JWTPayload->new();

    $importer->each(sub{

        my $payload = $_[0];

        $payload = $jwt_payloads->add( $payload );

        if( $payload ){

            $exporter->add( $payload );

        }
        else {

            say STDERR "jwt payload not accepted:";
            say STDERR " * $_" for @{ $jwt_payloads->last_errors() };

        }

    });

    $exporter->commit();

    0;
}

sub _get {

    my( $self, $payload_id ) = @_;

    unless( is_string( $payload_id ) ){

        say STDERR "payload identifier is not given";
        exit 1;

    }

    my $payload = LibreCat::JWTPayload->new()->get( $payload_id );

    to_yaml( $payload ) if defined( $payload );

    0;

}

sub _decode {

    my( $self, $token ) = @_;

    unless( is_string( $token ) ){

        say STDERR "no token given";
        exit 1;

    }

    my $payload = LibreCat::JWTPayload->new()->decode( $token, validate => 1 );

    unless( defined( $payload ) ){
        say STDERR "unable to decode token $token";
        exit 1;
    }

    to_yaml( $payload );

    0;

}

sub _export {

    my $self = $_[0];

    my $exporter = Catmandu::Exporter::YAML->new();

    $exporter->add_many( LibreCat::JWTPayload->new()->bag() );

    $exporter->commit();

    0;

}

sub _encode {
    my ($self, $payload_id) = @_;

    my $jwt_payloads = LibreCat::JWTPayload->new();

    unless( is_string( $payload_id ) ){
        say STDERR "no payload id given";
        exit 1;
    }

    my $payload = $jwt_payloads->get( $payload_id );

    unless( $payload ){
        say STDERR "no jwt payload for id $payload_id";
        exit 1;
    }

    my $jwt = $jwt_payloads->encode( $payload );

    say $jwt;

    return 0;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::jwt_payload - manage json web tokens

=head1 SYNOPSIS

    librecat jwt_payload add $yaml_file_with_payloads
    librecat jwt_payload get $payload_id
    librecat jwt_payload export
    librecat jwt_payload decode $token
    librecat jwt_payload encode $payload_id

=head1 commands

=head2 add <FILE>

What it does:

    * opens <FILE> or reads from stdin. YAML is expected
    * each record in this YAML file is a payload
    * each payload is validated, and, if valid, added to the table C<jwt_payload>
    * valid payload are exported back to YAML on stdout
    * invalid payloads are reported on stderr

For requirements for the JWT payload, see L<LibreCat::JWTPayload>

Example:

    $ ./bin/librecat jwt_payload add <<- "EOF"
    ---
    {}
    ...
    ---
    model: publication
    action: ["show","index"]
    ...
    ---
    model: department
    ...
    EOF

=head2 get <PAYLOAD_ID>

Exports <PAYLOAD_ID> in YAML format to stdout

Example:

    $ bin/librecat jwt_payload get 4cfd4db8-9459-11ea-a7d5-868a53d08d87
    ---
    _id: 4cfd4db8-9459-11ea-a7d5-868a53d08d87
    action:
    - index
    cql: status=returned
    date_created: 2020-05-12T14:03:05Z
    date_updated: 2020-05-12T14:03:05Z
    model: publication
    ...

=head2 export

Exports all payloads in YAML format to stdout

Example:

    $ bin/librecat jwt_payload export
    ---
    _id: 4cfd4db8-9459-11ea-a7d5-868a53d08d87
    action:
    - index
    cql: status=returned
    date_created: 2020-05-12T14:03:05Z
    date_updated: 2020-05-12T14:03:05Z
    model: publication
    ...

=head2 encode <PAYLOAD_ID>

Encode payload, identified by <PAYLOAD_ID>, to a JWT, and print to stdout

=head2 decode <JWT>

Decodes JWT into payload and exports it to the stdout in format YAML.

This way one can inspects its content, and see if the JWT is meant for this application.

The payload is only returned when the following requirements are met:

    * the token can be decrypted

    * the token is not expired (if applicable). See payload attribute C<exp>.

    * the token is ready to be used (if applicable). See payload attribute C<nbf>

    * the C<_id> in the payload corresponds to a record in the table C<jwt_payload>. If not, the token is considered "revoked".

Example:

    $ ./bin/librecat token decode eyJhbGciOiJIUzUxMiJ9.eyJtb2RlbCI6InB1YmxpY2F0aW9uIiwiZGF0ZV9jcmVhdGVkIjoiMjAyMC0wNS0xMlQxNDowMzowNVoiLCJjcWwiOiJzdGF0dXM9cmV0dXJuZWQiLCJfaWQiOiI0Y2ZkNGRiOC05NDU5LTExZWEtYTdkNS04NjhhNTNkMDhkODciLCJhY3Rpb24iOlsiaW5kZXgiXSwiZGF0ZV91cGRhdGVkIjoiMjAyMC0wNS0xMlQxNDowMzowNVoifQ.G55CDyYOHsw4m_v0QaUAb_BX3kLJmLIzJEIR6WpfASIo-aR1GXJnjEbryTk-wFeE0Qtta_PbjY6C7PttA9Evlw
    ---
    _id: 4cfd4db8-9459-11ea-a7d5-868a53d08d87
    action:
    - index
    cql: status=returned
    date_created: 2020-05-12T14:03:05Z
    date_updated: 2020-05-12T14:03:05Z
    model: publication
    ...

See also L<LibreCat::JWTPayload>

=cut
