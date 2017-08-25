package LibreCat::Cmd::id;

use Catmandu::Sane;
use LibreCat::Validator::Researcher;
use App::bmkpasswd qw(passwdcmp mkpasswd);
use Carp;
use parent qw(LibreCat::Cmd);

sub description {
    return <<EOF;
Usage:

librecat id [options] get
librecat id [options] set <id>

EOF
}

sub command {
    my ($self, $opts, $args) = @_;

    my $commands = qr/get|set/;

    unless (@$args) {
        $self->usage_error("should be one of $commands");
    }

    my $cmd = shift @$args;

    unless ($cmd =~ /^$commands$/) {
        $self->usage_error("should be one of $commands");
    }

    if ($cmd eq 'get') {
        return $self->_get(@$args);
    }
    elsif ($cmd eq 'set') {
        return $self->_set(@$args);
    }
}

sub _get {
    my ($self) = @_;

    my $bag  = LibreCat->store->bag('info');
    my $data = $bag->get('publication_id');

    printf "%s\n", $data->{latest};

    return 0;
}

sub _set {
    my ($seld, $id) = @_;

    croak "usage: $0 set <id>" unless defined($id);

    croak "id `$id` is not numeric" unless $id =~ /^\d+$/;

    my $bag = LibreCat->store->bag('info');
    my $data = $bag->add({_id => 'publication_id', latest => $id});

    printf "%s\n", $data->{latest};

    return 0;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::id - manage librecat generated record ids

=head1 SYNOPSIS

    librecat id get <id>
    librecat id set <id>

=cut
