package LibreCat::Worker;

use Catmandu::Sane;
use String::CamelCase qw(decamelize);
use Moo::Role;
use namespace::clean;

with 'LibreCat::Logger';

sub worker_functions {
    my ($self) = @_;
    my ($func) = reverse split '::', ref $self;
    $func = decamelize($func);
    [{$func => 'work'}];
}

1;

__END__

=pod

=head1 NAME

LibreCat::Worker - a base role for workers

=head1 SYNOPSIS

    package LibreCat::Worker::Drink;

    use Catmandu::Sane;
    use Moo;

    with 'LibreCat::Worker';

    # Default worker function is called 'work' -> mapped to the global 'drink'
    # worker
    sub work {
        my ($workload) = @_;
        log "drinking $workload->{beverage} ... ";
        sleep 3;
    }

    # with custom worker_functions
    package LibreCat::Worker::Drunkard;

    use Catmandu::Sane;
    use Moo;

    with 'LibreCat::Worker';

    # Register the 'booze' and 'have_hangover' global workers
    sub worker_functions {
        ['booze', {'have_hangover' => 'do_have_hangover'}];
    }

    sub booze {
        my ($workload) = @_;
        log "booze $workload->{beverage} ... ";
        sleep 3;
    }

    sub do_have_hangover {
        log "aargh ... ";
        sleep 9;
    }

    package main;

    use LibreCat::JobQueue;

    my $queue = LibreCat::JobQueue->new;

    # Adds a job for the 'LibreCat::Worker::Drink' worker
    $queue->add_job('drink', {beverage => 'beer'})

    # Adds a job for the 'LibreCat::Worker::Drunkard' worker
    $queue->add_job('booze', {beverage => 'wine'})
    $queue->add_job('have_hangover')

=cut
