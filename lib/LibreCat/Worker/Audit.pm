package LibreCat::Worker::Audit;

use Catmandu::Sane;
use Moo;
use LibreCat::Audit;
use namespace::clean;

with 'LibreCat::Worker';

# deprecated: no need to use a worker. Use LibreCat::Audit directly

has audit => (
    is => "ro",
    lazy => 1,
    default => sub { LibreCat::Audit->new(); },
    init_arg => undef
);

sub work {
    my ($self, $opts) = @_;

    $self->log->debugf("audit message: %s", $opts);

    my $rec = {
        id      => $opts->{id},
        bag     => $opts->{bag},
        process => $opts->{process},
        action  => $opts->{action},
        message => $opts->{message}
    };

    unless(
        $self->audit->add( $rec )
    ){

        $self->log->error( "validation audit failed: " . join(",",@{ $self->audit()->last_errors() }) );
        return;

    }

    1;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Worker::Audit - a worker for audits (if configured)

=head1 DESCRIPTION

Deprecated in favour of L<LibreCat::Audit>

=head1 SYNOPSIS

    use LibreCat::Worker::Audit;

    my $audit = LibreCat::Worker::Audit->new;
    $audit->work({
        id      => $opts->{id},
        bag     => $opts->{bag},
        process => $opts->{process},
        action  => $opts->{action},
        message => $opts->{message}
    });

=head2 SEE ALSO

L<LibreCat::Worker>

=cut
