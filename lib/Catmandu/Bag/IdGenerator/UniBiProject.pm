package Catmandu::Bag::IdGenerator::UniBiProject;

use Catmandu::Sane;
use Moo;

with 'Catmandu::Bag::IdGenerator';

sub generate {
    my ($self, $bag) = @_;

    my $all = [sort {$b->{_id} cmp $a->{_id}} @{$bag->to_array}];

    if (@$all > 0) {
        my $id = $all->[0]->{_id};
        $id =~ s/^P//g;
        $id++;
        return "P$id";
    }

    "P1";
}

1;
