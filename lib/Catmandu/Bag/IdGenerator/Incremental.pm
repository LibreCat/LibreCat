package Catmandu::Bag::IdGenerator::Incremental;

use Catmandu::Sane;
use Moo;

with 'Catmandu::Bag::IdGenerator';

sub generate {
    my ($self, $bag) = @_;

    my $id;

    $bag->store->transaction(
        sub {
            my $info_bag = $bag->store->bag('info');
            my $info_key = $bag->name.'_id';
            my $rec = $info_bag->get_or_add($info_key, {latest => '0'});
            $id = ++$rec->{latest};
            $rec->{latest} = "$rec->{latest}";
            $info_bag->add($rec);
            $info_bag->commit;
        }
    );

    "$id";
}

1;
