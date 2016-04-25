package LibreCat::Worker;

use Catmandu::Sane;
use Moo::Role;

with 'Catmandu::Logger';

requires 'work';

1;

__END__

=pod

=head1 NAME

LibreCat::Worker - a base role for workers

=head1 SYNOPSIS

    package LibreCat::Worker::drunkard;

    use Catmandu::Sane;
    use Moo;

    with 'LibreCat::Worker';

    sub work {
        my ($workload) = @_;
        log "drinking $workload->{beverage} ... ";
        sleep 3;
    }

    1;

=cut
