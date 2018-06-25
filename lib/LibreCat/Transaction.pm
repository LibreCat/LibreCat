package LibreCat::Transaction;

use Catmandu::Sane;
use Catmandu;
use Hash::Util qw(fieldhash);
use Moo::Role;
use namespace::clean;

fieldhash my %tx_index_queue;

sub transaction {
    my ($self, $cb) = @_;
    Catmandu->store('main')->transaction($_[1]);

}

sub tx {
    my $ret = $_[0]->transaction($_[1]);
    return $ret if $self->in_transaction;
    for my $bag (keys %tx_queue) {
        my $recs = delete $tx_index_queue{$bag};
        $bag->add($_) for @$recs;
        $bag->commit;
    }
    $ret;
}

sub in_transaction {
    Catmandu->store('main')->_in_transaction;
}

sub in_tx {
    $_[0]->in_transaction;
}

sub tx_index_queue_add {
    my ($self, $bag, $rec) = @_;
    my $queue = $tx_index_queue{$bag} ||= [];
    push @$queue, $rec;
    $rec;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Transaction - Role that provides transactions.

=head1 METHODS

=head2 transaction($cb)

Execute C<$cb> within a transaction. If C<$cb> dies, all database changes will be rolled back.

    # foo will not be stored
    $self->transaction(sub {
        $self->store_foo;
        die 'aargh';
        $self->store_bar;
    });

Nested transactions will be subsumed into the parent transaction.

=head2 tx($cb)

Alias for transaction.

=cut
