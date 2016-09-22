package Catmandu::Bag::IdGenerator::UniResearchGroup;

with 'Catmandu::Bag::IdGenerator';

has id_bag => (is => 'lazy');

sub _build_id_bag {
    Catmandu->store('default')->bag;
}

sub generate {
    my ($self, $bag) = @_;

    my $id = undef;

    $bag->store->transaction(sub {
        my $rec = $self->id_bag->get_or_add('1', {latest => '0'});
        $id = ++$rec->{latest};
        $self->id_bag->add($rec);
    });

    "RG$id";
}

1;
