package LibreCat::Cmd::token;

use Catmandu::Sane;
use Catmandu::Util qw(is_string check_hash_ref is_hash_ref);
use JSON::MaybeXS qw(decode_json);
use Carp;
use Try::Tiny;
use LibreCat;
use parent qw(LibreCat::Cmd);

sub description {
    return <<EOF;
Usage:

librecat token encode
librecat token encode '{"my": "payload"}'

EOF
}

sub command_opt_spec {
    my ($class) = @_;
    ();
}

sub command {
    my ($self, $opts, $args) = @_;

    my $commands = qr/(encode)/;

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
