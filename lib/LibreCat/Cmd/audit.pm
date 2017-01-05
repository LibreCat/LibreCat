package LibreCat::Cmd::audit;

use Catmandu::Sane;
use LibreCat::App::Helper;
use Carp;
use parent qw(LibreCat::Cmd);

sub description {
    return <<EOF;
Usage:

librecat audit [options] list
librecat audit [options] get <ID>

EOF
}

sub command_opt_spec {
    my ($class) = @_;
    ();
}

sub command {
    my ($self, $opts, $args) = @_;

    my $commands = qr/list|get/;

    unless (@$args) {
        $self->usage_error("should be one of $commands");
    }

    my $cmd = shift @$args;

    unless ($cmd =~ /^$commands$/) {
        $self->usage_error("should be one of $commands");
    }

    binmode(STDOUT, ":encoding(utf-8)");

    if ($cmd eq 'list') {
        return $self->_list(@$args);
    }
    elsif ($cmd eq 'get') {
        return $self->_get(@$args);
    }
}

sub _list {
    my ($self) = @_;

    my $it = LibreCat::App::Helper::Helpers->new->backup_audit();

    my $count = $it->each(
        sub {
            my ($item)   = @_;
            my $id       = $item->{id}  // '';
            my $message  = $item->{message} // '';

            printf "%s %s %-36.36s %s\n"
                    , $item->{_id}
                    , $item->{date_created}
                    , $id
                    , $message;
        }
    );
    print "count: $count\n";

    return 0;
}

sub _get {
    my ($seld, $id) = @_;

    croak "usage: $0 get <id>" unless defined($id);

    my $data = LibreCat::App::Helper::Helpers->new->backup_audit->get($id);

    Catmandu->export($data, 'YAML') if $data;

    return $data ? 0 : 2;
}


1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::audit - manage librecat audit messages

=head1 SYNOPSIS

    librecat audit list
    librecat audit get <ID>

=cut
