package LibreCat::Worker;

use Catmandu::Sane;
use String::CamelCase qw(decamelize);
use Moo::Role;
use namespace::clean;

with 'Catmandu::Logger';

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

    # the default worker function is the underscored package name mapped to the
    # 'work' method
    package LibreCat::Worker::Drink;

    use Catmandu::Sane;
    use Moo;

    with 'LibreCat::Worker';

    sub work {
        my ($workload) = @_;
        log "drinking $workload->{beverage} ... ";
        sleep 3;
    }

    # $queue->add_job('drink', {beverage => 'beer'})

    # with custom worker_functions
    package LibreCat::Worker::drunkard;

    use Catmandu::Sane;
    use Moo;

    with 'LibreCat::Worker';

    sub worker_functions {
        ['drink', {'have_hangover' => 'do_have_hangover'}];
    }

    sub drink {
        my ($workload) = @_;
        log "drinking $workload->{beverage} ... ";
        sleep 3;
    }

    sub do_have_hangover {
        log "aargh ... ";
        sleep 9;
    }

    # $queue->add_job('drink', {beverage => 'wine'})
    # $queue->add_job('drink', {beverage => 'beer'})
    # $queue->add_job('have_hangover')

=cut
