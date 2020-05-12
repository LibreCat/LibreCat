package LibreCat::Cmd::token;

use Catmandu::Sane;
use Catmandu::Util qw(is_string check_hash_ref is_hash_ref);
use JSON::MaybeXS qw(decode_json);
use Carp;
use Try::Tiny;
use LibreCat;
use Catmandu::Exporter::YAML;
use parent qw(LibreCat::Cmd);

sub description {
    return <<EOF;
Usage:

librecat token encode
librecat token encode '{ "action": ["show","index"], "model": "publication", "cql" : "status=public" }'
librecat token export

EOF
}

sub command_opt_spec {
    my ($class) = @_;
    ();
}

sub command {
    my ($self, $opts, $args) = @_;

    my $commands = qr/(encode|decode|reencode|export)/;

    unless (@$args) {
        $self->usage_error("should be one of $commands");
    }

    my $cmd = shift @$args;

    unless ($cmd =~ /^$commands$/) {
        $self->usage_error("should be one of $commands");
    }

    binmode(STDOUT, ":encoding(utf-8)");

    if ($cmd eq 'encode') {
        return $self->_encode(@$args);
    }
    elsif( $cmd eq 'decode' ){
        return $self->_decode(@$args);
    }
    elsif( $cmd eq 'export' ){
        return $self->_export(@$args);
    }
    elsif( $cmd eq 'reencode' ){
        return $self->_reencode(@$args);
    }

}

sub _encode {
    my ($self, $json) = @_;

    my $payload;

    if (is_string($json)) {

        my $parse_error;

        try {
            $payload = decode_json($json);
        }catch {
            $parse_error = $_;
        };

        if( $parse_error ){
            say STDERR "unable to parse json: $parse_error";
            return 1;
        }

        unless( is_hash_ref( $payload ) ){
            say STDERR "supplied payload should be a hash";
            return 1;
        }

    }
    else {

        $payload = {};

    }

    my( $token,@errors ) = LibreCat->instance()->token()->encode( $payload );

    unless( $token ){

        say STDERR "jwt payload not accepted:";
        say STDERR " * $_" for @errors;
        return 1;

    }

    say $token;
    return 0;
}

sub _decode {

    my( $self, $token ) = @_;

    my $payload = LibreCat->instance()->token()->decode( $token );

    unless( defined( $payload ) ){
        say STDERR "unable to decode token $token";
        exit 1;
    }

    my $exporter = Catmandu::Exporter::YAML->new();

    $exporter->add( $payload );

    $exporter->commit();

    0;

}

sub _export {

    my $self = $_[0];

    my $exporter = Catmandu::Exporter::YAML->new();

    $exporter->add_many( LibreCat->instance()->token()->bag() );

    $exporter->commit();

    0;

}

sub _reencode {
    my ($self, $id) = @_;

    my $payload = LibreCat->instance()->token()->bag()->get( $id );

    unless( $payload ){
        say STDERR "no jwt payload for id $id";
        exit 1;
    }

    my( $token,@errors ) = LibreCat->instance()->token()->payload_encode( $payload );

    unless( $token ){

        say STDERR "strange, old jwt payload not accepted:";
        say STDERR " * $_" for @errors;
        return 1;

    }

    say $token;
    return 0;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::token - manage json web tokens

=head1 SYNOPSIS

    librecat token encode

=head1 commands

=head2 encode

Prints encoded json web token.

=cut
