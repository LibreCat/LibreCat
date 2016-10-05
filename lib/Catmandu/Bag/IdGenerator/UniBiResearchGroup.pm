package Catmandu::Bag::IdGenerator::UniBiResearchGroup;

use Catmandu::Sane;
use Moo;

with 'Catmandu::Bag::IdGenerator';

sub generate {
    my ($self, $bag) = @_;

    my @all = sort {$b->{_id} cmp $a->{_id}} @{$bag->to_array};

    if (@all > 0) {
        my $id = $all[0]->{_id};
        $id =~ s/^RG//g;
        $id++;
        return "RG$id";
    }

    "RG1";
}

1;
