package LibreCat::Cmd::token;

use Catmandu::Sane;
use Catmandu;
use LibreCat -self;
use Carp;
use parent qw(LibreCat::Cmd);

sub description {
    return <<EOF;
Usage:

librecat token encode

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
    say librecat->token->encode;
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
