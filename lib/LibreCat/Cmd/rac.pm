package LibreCat::Cmd::rac;

use Catmandu::Sane;
use Catmandu;
use Date::Simple qw(date today);
use parent qw(LibreCat::Cmd);

sub description {
    return <<EOF;
Usage:

librecat rac

EOF
}

sub command_opt_spec {
    my ($class) = @_;
    ();
}

sub command {
    my ($self, $opts, $args) = @_;

    $self->_cron(@$args);
}

sub _cron {
    my $bag = Catmandu->store('main')->bag('reqcopy');

    $bag->each(
        sub {
            my $rec  = $_[0];
            my $diff = today() - date($rec->{date_expires});

            if ($diff > 0) {
                $bag->delete($rec->{_id});
            }
        }
    );

    return 0;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::rac - update the request-a-copy db

=cut
