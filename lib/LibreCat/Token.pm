package LibreCat::Token;

use Catmandu::Sane;
use Moo;
use Crypt::JWT ':all';
use namespace::clean;

with 'LibreCat::Logger';

has secret => (is => 'ro', required => 1);

sub encode {
    my ($self, $payload) = @_;
    $payload //= {};
    my $token = encode_jwt(payload => $payload, key => $self->secret, alg => 'HS512');
    if ($self->log->is_debug) {
        $self->log->debugf("Encoded JWT token $token %s", $payload);
    }
    $token;
}

sub decode {
    my ($self, $token) = @_;
    if ($self->log->is_debug && !defined $token) {
        $self->log->debug("JWT token missing");
        return;
    }
    try {
        my $payload = decode_jwt(token => $token, key => $self->secret, accepted_alg => 'HS512');
        if ($self->log->is_debug) {
            $self->log->debugf("Decoded JWT token $token %s", $payload);
        }
        $payload;
    } catch {
        if ($self->log->is_debug) {
            $self->log->debug("Invalid JWT token $token");
        }
        undef;
    };
}

1;
