package LibreCat::Cmd::index;

use Catmandu::Sane;
use LibreCat::Queue;
use parent qw(LibreCat::Cmd);
use Data::Dumper;

sub command_opt_spec {
    my ($class) = @_;
    (
        ['background|bg', ""],
        ['bag=s', "", {required => 1}],
        ['id=s', ""],
    );
}

sub command {
    my ($self, $opts, $args) = @_;

    my $queue = LibreCat::Queue->new;
    if ($opts->id) {
        my $job_id = $queue->add_job('index_record',
            {bag => $opts->bag, id => $opts->bag});
        return;
    }

    my $job_id = $queue->add_job('index_all', {bag => $opts->bag});

    if ($opts->background) {
        say $job_id;
    } else {
        say "job $job_id";

        my $job;
        my $prev_n = 0;
        while (1) {
            $job = $queue->job_status($job_id);
            if ($job->queued) {
                say 'waiting for worker';
            } elsif ($job->running) {
                my ($n, $total) = $job->progress;
                if ($n > $prev_n) {
                    say "indexing $n/$total";
                    $prev_n = $n;
                }
            } else {
                say 'done';
                return;
            }
            sleep 1;
        }
    }
}

1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::index - manage index jobs

=cut

