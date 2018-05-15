package LibreCat::JobStatus;

use Catmandu::Sane;
use namespace::clean;

sub new {
    bless $_[1];
}

sub queued {

    # known && not running
    $_[0]->[0] && !$_[0]->[1];
}

sub running {

    # known && running
    $_[0]->[0] && $_[0]->[1];
}

sub done {

    # not known
    !$_[0]->[0];
}

sub progress {
    return $_[0]->[2], $_[0]->[3];
}

1;

__END__

=pod

=head1 NAME

LibreCat::JobStatus - get the status for a job

=head1 SYNOPSIS

    use LibreCat::JobStatus;

    my $s = LibreCat::JobStatus->new(\@status);

    $s->running && print "job is running";

=head1 METHODS

=over

=item queued

Returns true value if job is queued but not running.

=item running

Returns true value if job is running.

=item done

Returns true value if job is not in queue anymore.

=item progress

Returns the progess of the job.

=back

=head1 SEE ALSO

L<LibreCat::JobQueue>

=cut
