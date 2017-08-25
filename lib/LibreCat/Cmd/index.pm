package LibreCat::Cmd::index;

use Catmandu::Sane;
use LibreCat::JobQueue;
use parent qw(LibreCat::Cmd);
use Data::Dumper;
use LibreCat::Index;

sub description {
    return <<EOF;
Usage:

librecat index [--background] [--id=...] [bag]
librecat index [--status] [--croak]

EOF
}

sub command_opt_spec {
    my ($class) = @_;
    (['background|bg', ""], ['id=s', ""], ['status', ""], );
}

sub command {
    my ($self, $opts, $args) = @_;

    my $bag = shift @$args;

    unless ($bag or $opts->status) {
        $self->usage_error("need a bag as argument");
    }

    if($opts->status){
        my $status = LibreCat::Index->get_status;
        print Dumper $status;

    }
    else {
        my $queue = LibreCat::JobQueue->new;

        if ($opts->id) {
            my $job_id
                = $queue->add_job('indexer', {bag => $bag, id => $opts->id});
            return $job_id if $opts->background;
            print "[$job_id]:";
            while (1) {
                print "+";
                my $job = $queue->job_status($job_id);
                last if $job->done;
                sleep 1;
            }
            print "DONE\n";
            return;
        }

        my $job_id = $queue->add_job('indexer', {bag => $bag});

        if ($opts->background) {
            say $job_id;
        }
        else {
            say "job $job_id";

            my $job;
            my $prev_n = 0;
            while (1) {
                $job = $queue->job_status($job_id);
                if ($job->queued) {
                    say 'waiting for worker';
                }
                elsif ($job->running) {
                    my ($n, $total) = $job->progress;
                    if ($n > $prev_n) {
                        say "indexing $n/$total";
                        $prev_n = $n;
                    }
                }
                else {
                    say 'done';
                    return;
                }
                sleep 1;
            }
        }
    }

}

1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::index - manage index jobs

=head1 SYNOPSIS

    librecat index [--background] [--id=...] [bag]

=cut
