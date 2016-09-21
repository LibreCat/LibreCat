package Catmandu::Bag::IdGenerator::UniBiDefault;

use Catmandu::Sane;
use Moo;

with 'Catmandu::Bag::IdGenerator';

sub generate {
    my ($self, $bag) = @_;

    $bag->store->transaction(sub {
        my $rec = $bag->get_or_add('1', {latest => '0'});
        my $id = ++$rec->{latest};
        $self->bag->add($rec);
        $id;
    });
}

1;
