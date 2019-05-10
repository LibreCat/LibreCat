package LibreCat::Token;

use Catmandu::Sane;
use Moo;
use Crypt::JWT ':all';
use namespace::clean;

has secret => (is => 'ro', required => 1);

sub encode {
    my ($self, $payload) = @_;
    encode_jwt(payload => $payload // {}, key => $self->secret, alg => 'HS512');
}

sub decode {
    my ($self, $token) = @_;
    $token // return;
    try {
        decode_jwt(token => $token, key => $self->secret, accepted_alg => 'HS512');
    } catch {
    };
}

1;
