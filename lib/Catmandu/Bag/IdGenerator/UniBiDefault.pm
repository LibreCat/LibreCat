package Catmandu::Bag::IdGenerator::UniBiDefault;

use Catmandu::Sane;
use Moo;

with 'Catmandu::Bag::IdGenerator';

has id_store => (is => 'lazy');

sub _build_id_store {
    Catmandu->store('default');
}

sub generate {
    my ($self) = @_;

    my $id = undef;

    $self->id_store->transaction(sub {
        my $rec = $self->id_store->bag->get_or_add('1', {latest => '0'});
        $id = ++$rec->{latest};
        $self->id_store->bag->add($rec);
    });

    "$id";
}


1;
