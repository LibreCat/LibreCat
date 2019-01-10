package LibreCat::Cmd::audit;

use Catmandu::Sane;
use LibreCat::App::Helper;
use Carp;
use POSIX qw(strftime);
use parent qw(LibreCat::Cmd);

sub description {
    return <<EOF;
Usage:

librecat audit list [options] [<RECORD-ID>]

An 'audit' worker should be up and running to
store messages:

Hint:

bin/librecat worker audit start --workers 1 --supervise

EOF
}

sub command_opt_spec {
    my ($class) = @_;
    ();
}

sub command {
    my ($self, $opts, $args) = @_;

    my $commands = qr/^(list)$/;

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
}

sub _list {
    my ($self, $pid) = @_;

    my $it = Catmandu->store('main')->bag('audit');

    if ($pid) {
        $it = $it->select(id => $pid)->sorted(
            sub {
                $_[0]->{time} cmp $_[1]->{time};
            }
        );
    }

    my $count = $it->each(
        sub {
            my ($item)  = @_;
            my $id      = $item->{id} // '';
            my $process = $item->{process} // '';
            my $action  = $item->{action} // '';
            my $message = $item->{message} // '';
            my $time    = strftime("%Y-%m-%dT%H:%M:%SZ",
                gmtime($item->{time} // 0));

            printf "%s %s %s %s %s\n", $time, $id, $process, $action,
                $message;
        }
    );

    print "count: $count\n";

    return 0;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::audit - manage librecat audit messages

=head1 SYNOPSIS

    librecat audit list [options] [<RECORD-ID>]

    An 'audit' worker should be up and running to
    store messages:

    Hint:

    bin/librecat worker audit start --workers 1 --supervise
    
=cut
